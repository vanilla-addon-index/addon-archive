-- Ashen Builds combat simulator: planner controls.
--
-- A SIM DPS button under the trinket slots, a progress bar while fights run
-- and the result underneath. Hovering the result shows the full breakdown;
-- shift-clicking it opens one fight's combat log. The gear button opens the
-- per-class settings (encounter, rotation, buffs and debuffs).

local AB = AshenBuilds
local S = AshenSim

local function Models() return S.Models or {} end
local function ModelFor(className) return Models()[className or ""] end

local function Color(t) return t[1], t[2], t[3] end
local function Hex(r, g, b) return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255) end

local function BuildSignature(build)
  local ok, code = pcall(function() return AB:ExportBuild(build) end)
  return ok and code or tostring(math.random())
end

---------------------------------------------------------------------------
-- Result panel.
---------------------------------------------------------------------------
function AB:CreateSimPanel()
  if self.simPanel or not self.frame then return end
  local f = self.frame
  -- Part of the Planner page (under Trinket 2), so it hides with the gear on other tabs.
  local page = self.plannerPage or f
  local p = CreateFrame("Frame", nil, page); p:SetWidth(155); p:SetHeight(84)
  p:SetPoint("TOPLEFT", page, "TOPLEFT", 775, -604)
  self.simPanel = p

  local run = CreateFrame("Button", nil, p, "UIPanelButtonTemplate"); run:SetWidth(122); run:SetHeight(24)
  run:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0); run:SetText("SIM DPS"); self:SkinButton(run, "ember")
  run:SetScript("OnClick", function() AB:ToggleSim() end)
  run:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    if S.IsRunning() then GameTooltip:SetText("Click to cancel the simulation", 1, .82, 0)
    else
      GameTooltip:SetText("Simulate this build's DPS", 1, .82, 0)
      if not ModelFor(AB.current.class) then GameTooltip:AddLine("Only Warrior is supported so far.", 1, .35, .35, 1) end
      GameTooltip:AddLine("Settings (buffs, target, rotation) are on the gear button.", .8, .8, .8, 1)
    end
    GameTooltip:Show()
  end)
  run:SetScript("OnLeave", function() GameTooltip:Hide() end)
  p.run = run

  local gear = CreateFrame("Button", nil, p, "UIPanelButtonTemplate"); gear:SetWidth(29); gear:SetHeight(24)
  gear:SetPoint("LEFT", run, "RIGHT", 4, 0); gear:SetText(""); self:SkinButton(gear, "ember")
  local icon = gear:CreateTexture(nil, "OVERLAY"); icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
  icon:SetWidth(16); icon:SetHeight(16); icon:SetPoint("CENTER", gear, "CENTER", 0, 0); icon:SetTexCoord(.08, .92, .08, .92)
  gear:SetScript("OnClick", function() AB:OpenSimSettings() end)
  gear:SetScript("OnEnter", function() GameTooltip:SetOwner(this, "ANCHOR_LEFT"); GameTooltip:SetText("Simulation settings", 1, .82, 0); GameTooltip:AddLine("Saved separately for each class.", .8, .8, .8); GameTooltip:Show() end)
  gear:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local bar = CreateFrame("StatusBar", nil, p); bar:SetWidth(155); bar:SetHeight(16)
  bar:SetPoint("TOPLEFT", run, "BOTTOMLEFT", 0, -8)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); bar:SetStatusBarColor(1, .45, .16)
  bar:SetMinMaxValues(0, 1); bar:SetValue(0)
  local bg = bar:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(bar); bg:SetTexture(0, 0, 0, .6)
  bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
  bar:Hide(); p.bar = bar

  -- The result is a button so it can show the breakdown and open the log.
  local res = CreateFrame("Button", nil, p); res:SetWidth(155); res:SetHeight(46)
  res:SetPoint("TOPLEFT", run, "BOTTOMLEFT", 0, -4)
  res.value = res:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); res.value:SetPoint("TOP", res, "TOP", 0, -2)
  res.sub = res:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); res.sub:SetPoint("TOP", res.value, "BOTTOM", 0, -3); res.sub:SetWidth(155)
  res:SetScript("OnEnter", function() AB:ShowSimTooltip(this) end)
  res:SetScript("OnLeave", function() GameTooltip:Hide() end)
  res:SetScript("OnClick", function() if IsShiftKeyDown() then AB:ShowSimLog() end end)
  p.result = res
  self:UpdateSimPanel()
end

function AB:UpdateSimPanel()
  local p = self.simPanel
  if not p then return end
  local supported = ModelFor(self.current.class) ~= nil
  if S.IsRunning() then p.run:SetText("CANCEL") else p.run:SetText("SIM DPS") end
  if supported or S.IsRunning() then p.run:Enable() else p.run:Disable() end
  local r = self.simResult
  local res = p.result
  if S.IsRunning() then p.bar:Show(); res:Hide(); return end
  p.bar:Hide(); res:Show()
  local g, dim = self.THEME.gold, self.THEME.dim
  if self.simError and self.simErrorSig ~= BuildSignature(self.current) then self.simError = nil end
  if not supported then
    res.value:SetText(""); res.sub:SetText("|cff8d96a8"..(self.current.class or "This class").." sim coming later|r")
  elseif self.simError then
    res.value:SetText(""); res.sub:SetText("|cffff5555"..self.simError.."|r")
  elseif r and r.class == self.current.class then
    local stale = r.signature ~= BuildSignature(self.current)
    res.value:SetText(string.format("%.1f DPS", r.mean))
    if stale then res.value:SetTextColor(Color(dim)) else res.value:SetTextColor(Color(g)) end
    local acc = r.accuracy == "HIGH" and "|cff7fd97fHIGH|r" or "|cffffb347PARTIAL|r"
    if stale then res.sub:SetText("|cff8d96a8Build changed - sim again|r")
    else res.sub:SetText(string.format("+/-%.1f  |  %s", r.ciHigh - r.mean, acc)) end
  else
    res.value:SetText(""); res.sub:SetText("|cff8d96a8Click SIM DPS to simulate|r")
  end
end

-- Everything in the settings that changes the fights, as one string.
function AB:SimSettingsKey(cfg)
  local parts, k, v = {}
  for k, v in pairs(cfg) do
    if type(v) == "table" then local k2; for k2 in pairs(v) do table.insert(parts, k.."."..tostring(k2)) end
    else table.insert(parts, k.."="..tostring(v)) end
  end
  table.sort(parts)
  return table.concat(parts, ";")
end

function AB:ToggleSim()
  if S.IsRunning() then
    S.Cancel(); self.simError = "Cancelled"; self.simErrorSig = BuildSignature(self.current); self:UpdateSimPanel(); return
  end
  local model = ModelFor(self.current.class)
  if not model then return end
  local cfg = model.GetSettings()
  local char, err = model.BuildCharacter(self.current, cfg)
  self.simError = nil
  if not char then self.simError = err; self.simErrorSig = BuildSignature(self.current); self:UpdateSimPanel(); return end
  local accuracy, reasons, rot = model.Accuracy(char, cfg)
  local signature = BuildSignature(self.current)
  local class = self.current.class
  local p = self.simPanel
  p.bar:SetValue(0); p.bar.text:SetText("0%")
  -- Same seed = same fights, so re-simming a build gives the same number and build changes compare cleanly.
  local seed = cfg.seed
  if cfg.randomSeed then seed = math.floor(math.mod(GetTime() * 1000, 2000000000)) + 1 end
  S.Start({model = model, char = char, cfg = cfg, iterations = cfg.iterations, seed = seed,
    onProgress = function(i, n) p.bar:SetValue(i / n); p.bar.text:SetText(math.floor(100 * i / n).."%") end,
    onDone = function(sum)
      local mean, sd, lo, hi = S.Stats(sum)
      local prev = AB.simResult
      AB.simResult = {class = class, mean = mean, sd = sd, ciLow = lo, ciHigh = hi, summary = sum, accuracy = accuracy,
        reasons = reasons, rotation = rot, char = char, cfg = cfg, model = model, signature = signature,
        previous = nil}
      -- Same seeds and settings mean the same fights, so the difference is the build change alone.
      if prev and prev.class == class and prev.cfg == cfg and prev.settingsKey == AB:SimSettingsKey(cfg) then
        if prev.signature ~= signature then AB.simResult.previous = prev.mean else AB.simResult.previous = prev.previous end
      end
      AB.simResult.settingsKey = AB:SimSettingsKey(cfg)
      AB:UpdateSimPanel()
    end,
    onError = function(msg) AB.simError = "Sim error (see chat)"; AB.simErrorSig = signature; AB.Print("Simulation error: "..tostring(msg)); AB:UpdateSimPanel() end})
  self:UpdateSimPanel()
end

---------------------------------------------------------------------------
-- Breakdown tooltip.
---------------------------------------------------------------------------
local RESULT_ORDER = {"miss", "dodge", "parry", "glance", "crit", "hit"}
local RESULT_NAMES = {miss = "Miss", dodge = "Dodge", parry = "Parry", glance = "Glance", crit = "Crit", hit = "Hit"}

local function Pct(n, d) if not d or d == 0 then return 0 end return 100 * n / d end

function AB:ShowSimTooltip(owner)
  local r = self.simResult
  if not r or r.class ~= self.current.class then return end
  local sum = r.summary
  local fights = sum.n
  local g = self.THEME.gold
  GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
  GameTooltip:SetText(string.format("Simulated DPS: %.1f", r.mean), Color(g))
  GameTooltip:AddLine(string.format("95%% confidence %.1f - %.1f  (spread %.0f - %.0f)", r.ciLow, r.ciHigh, sum.min or 0, sum.max or 0), .85, .85, .85)
  GameTooltip:AddLine(string.format("%d fights of %ds vs level %d: %d armor, %d after debuffs", fights, r.cfg.duration, r.cfg.targetLevel, r.cfg.targetArmor, r.char.targetArmor), .7, .7, .7)
  if r.cfg.boss and r.cfg.boss ~= "custom" then GameTooltip:AddLine("Boss: "..r.cfg.boss, .7, .7, .7) end
  local rotName = r.rotation.key
  local i
  for i = 1, table.getn(S.Warrior.ROTATIONS) do if S.Warrior.ROTATIONS[i].key == rotName then rotName = S.Warrior.ROTATIONS[i].name end end
  GameTooltip:AddDoubleLine("Rotation", rotName, .7, .7, .7, 1, 1, 1)
  if r.previous then
    local d = r.mean - r.previous
    GameTooltip:AddDoubleLine("Change vs last build (same fights)", string.format("%s%.1f", d >= 0 and "+" or "", d), .7, .7, .7, d >= 0 and .5 or 1, d >= 0 and 1 or .4, .4)
  end
  GameTooltip:AddDoubleLine("Accuracy", r.accuracy, .7, .7, .7, r.accuracy == "HIGH" and .5 or 1, r.accuracy == "HIGH" and .85 or .7, r.accuracy == "HIGH" and .5 or .3)

  -- Damage by source.
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("DAMAGE", Color(g))
  local names, name = {}
  for name in pairs(sum.sources) do if sum.sources[name].dmg > 0 then table.insert(names, name) end end
  table.sort(names, function(a, b) return sum.sources[a].dmg > sum.sources[b].dmg end)
  local total = 0
  for i = 1, table.getn(names) do total = total + sum.sources[names[i]].dmg end
  for i = 1, table.getn(names) do
    local s = sum.sources[names[i]]
    local per = (names[i] == "Deep Wounds" or names[i] == "Rend") and "" or string.format("  x%.1f", s.casts / fights)
    GameTooltip:AddDoubleLine(names[i]..per, string.format("%.1f  (%.1f%%)", s.dmg / sum.duration, Pct(s.dmg, total)), 1, 1, 1, 1, 1, 1)
  end

  -- Attack table for white swings.
  local function TableLine(label, src)
    local s = sum.sources[src]
    if not s or s.casts == 0 then return end
    local parts, k = {}
    for k = 1, table.getn(RESULT_ORDER) do
      local key = RESULT_ORDER[k]
      if s.results[key] then table.insert(parts, string.format("%s %.1f", RESULT_NAMES[key], Pct(s.results[key], s.casts))) end
    end
    GameTooltip:AddLine(label..string.format(" (%.1f swings): ", s.casts / fights)..table.concat(parts, "  "), .85, .85, .85, 1)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("ATTACK TABLE (%)", Color(g))
  TableLine("Main hand", "Main Hand"); TableLine("Off hand", "Off Hand")
  local c = sum.counters
  local function Per(key) return (c[key] or 0) / fights end
  if c["rage.gen"] then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("RAGE PER FIGHT", Color(g))
    GameTooltip:AddDoubleLine("Generated", string.format("%.0f", Per("rage.gen")), .85, .85, .85, 1, 1, 1)
    local gen, parts, j = {{"white", "white"}, {"dodge", "dodged"}, {"unbridled", "Unbridled Wrath"}, {"bloodrage", "Bloodrage"}, {"berserkerRage", "Berserker Rage"}, {"refund", "refunds"}}, {}
    for j = 1, table.getn(gen) do local v = Per("rage.gen."..gen[j][1]); if v >= 0.5 then table.insert(parts, string.format("%s %.0f", gen[j][2], v)) end end
    GameTooltip:AddLine("   "..table.concat(parts, ", "), .7, .7, .7, 1)
    GameTooltip:AddDoubleLine("Spent", string.format("%.0f", Per("rage.spent")), .85, .85, .85, 1, 1, 1)
    local spent, k = {}
    for k in pairs(c) do
      local _, _, what = string.find(k, "^rage%.spent%.(.+)$")
      if what then table.insert(spent, {what, c[k] / fights}) end
    end
    table.sort(spent, function(a, b) return a[2] > b[2] end)
    local parts = {}
    for k = 1, table.getn(spent) do table.insert(parts, string.format("%s %.0f", spent[k][1], spent[k][2])) end
    if table.getn(parts) > 0 then GameTooltip:AddLine("   "..table.concat(parts, ", "), .7, .7, .7, 1) end
    GameTooltip:AddDoubleLine("Wasted (over cap)", string.format("%.1f", Per("rage.wasted")), .85, .85, .85, 1, 1, 1)
    if c["rage.stanceLost"] then GameTooltip:AddDoubleLine("Lost to stance swaps", string.format("%.1f", Per("rage.stanceLost")), .85, .85, .85, 1, 1, 1) end
  end

  -- Procs and buff uptimes.
  local ups = {}
  for name in pairs(sum.uptime) do if sum.uptime[name] > 0 then table.insert(ups, name) end end
  table.sort(ups, function(a, b) return sum.uptime[a] > sum.uptime[b] end)
  if table.getn(ups) > 0 then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("UPTIME", Color(g))
    for i = 1, table.getn(ups) do GameTooltip:AddDoubleLine(ups[i], string.format("%.1f%%", Pct(sum.uptime[ups[i]], sum.duration)), .85, .85, .85, 1, 1, 1) end
  end
  local procs, k = {}
  for k in pairs(c) do local _, _, what = string.find(k, "^proc%.(.+)$"); if what then table.insert(procs, string.format("%s %.1f", what, c[k] / fights)) end end
  if c["extraAttacks"] then table.insert(procs, string.format("extra attacks %.1f", Per("extraAttacks"))) end
  if table.getn(procs) > 0 then table.sort(procs); GameTooltip:AddLine("Procs per fight: "..table.concat(procs, ", "), .7, .7, .7, 1) end

  if table.getn(r.reasons) > 0 then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("NOT FULLY SIMULATED", 1, .6, .3)
    for i = 1, math.min(8, table.getn(r.reasons)) do GameTooltip:AddLine(r.reasons[i], 1, .45, .45, 1) end
    if table.getn(r.reasons) > 8 then GameTooltip:AddLine("...and "..(table.getn(r.reasons) - 8).." more (see the combat log window)", 1, .45, .45) end
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Shift-click: one fight's combat log and mechanic sources", .5, .8, 1)
  GameTooltip:Show()
end

---------------------------------------------------------------------------
-- One-fight combat log (debug trace).
---------------------------------------------------------------------------
function AB:ShowSimLog()
  local r = self.simResult
  if not r then return end
  local f = self.simLogFrame
  if not f then
    f = CreateFrame("Frame", "AshenBuildsSimLog", UIParent); f:SetWidth(560); f:SetHeight(520); f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self:WindowBackdrop(f); self:SetupWindow(f); f:Hide(); self.simLogFrame = f
    self:ApplyEmberBackground(f, 10, 0.5, 0.5, 0.5); self:AddEmberHeader(f, 34)
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); title:SetPoint("TOP", f, "TOP", 0, -16); title:SetText("SIMULATION LOG")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    f.info = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.info:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -44); f.info:SetWidth(520); f.info:SetJustifyH("LEFT")
    local scroll = CreateFrame("ScrollFrame", "AshenBuildsSimLogScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -66); scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -38, 18)
    local edit = CreateFrame("EditBox", "AshenBuildsSimLogText", scroll); edit:SetMultiLine(true); edit:SetAutoFocus(false)
    edit:SetFontObject(GameFontHighlightSmall); edit:SetWidth(495); edit:SetHeight(400)
    edit:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    edit:SetScript("OnTextChanged", function() this:GetParent():UpdateScrollChildRect() end)
    scroll:SetScrollChild(edit); f.edit = edit
  end
  local seed = S.IterationSeed(r.cfg.seed, 1)
  local log = {}
  local ok, sim = pcall(S.RunFight, r.model, r.char, r.cfg, seed, log)
  local lines = {}
  table.insert(lines, "Fight 1 of the last run (seed "..seed.."): "..(ok and string.format("%.1f DPS", sim.dps) or ("error: "..tostring(sim))))
  table.insert(lines, "")
  local i
  for i = 1, table.getn(log) do table.insert(lines, log[i]) end
  table.insert(lines, "")
  table.insert(lines, "MECHANIC SOURCES")
  for i = 1, table.getn(S.MechanicOrder) do
    local m = S.Mechanics[S.MechanicOrder[i]]
    table.insert(lines, "["..m.status.."] "..m.key..": "..(m.note or "").." ("..m.source..")")
  end
  if table.getn(r.reasons) > 0 then
    table.insert(lines, ""); table.insert(lines, "NOT FULLY SIMULATED")
    for i = 1, table.getn(r.reasons) do table.insert(lines, r.reasons[i]) end
  end
  f.info:SetText("Every event of one fight. Same build and settings always give the same fight.")
  f.edit:SetText(table.concat(lines, "\n"))
  f.edit:SetHeight(12 * table.getn(lines) + 20)
  f:Show()
end

---------------------------------------------------------------------------
-- Settings window (per class).
---------------------------------------------------------------------------
local ITERATIONS = {100, 500, 1000, 5000, 10000}
local editCount = 0

local function NumberRow(parent, label, x, y, get, set)
  editCount = editCount + 1
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); fs:SetText(label)
  local e = CreateFrame("EditBox", "AshenBuildsSimEdit"..editCount, parent, "InputBoxTemplate"); e:SetWidth(52); e:SetHeight(20)
  e:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 128, y + 4); e:SetAutoFocus(false); e:SetMaxLetters(6)
  local function Commit() local v = tonumber(this:GetText()); if v then set(v) end; this:SetText(tostring(get())) end
  e:SetScript("OnEnterPressed", function() Commit(); this:ClearFocus() end)
  e:SetScript("OnEditFocusLost", Commit)
  e:SetScript("OnEscapePressed", function() this:SetText(tostring(get())); this:ClearFocus() end)
  e.Refresh = function() e:SetText(tostring(get())) end
  return e
end

local function CycleRow(parent, label, x, y, values, names, get, set)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); fs:SetText(label)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate"); b:SetWidth(120); b:SetHeight(20)
  b:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 84, y + 4); AB:SkinButton(b, "cycle")
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b.Refresh = function()
    local v, i = get()
    for i = 1, table.getn(values) do if values[i] == v then b:SetText(names[i]) end end
  end
  b:SetScript("OnClick", function()
    local v, i, idx = get(), nil, 1
    for i = 1, table.getn(values) do if values[i] == v then idx = i end end
    idx = idx + (arg1 == "RightButton" and -1 or 1)
    if idx > table.getn(values) then idx = 1 elseif idx < 1 then idx = table.getn(values) end
    set(values[idx]); b.Refresh()
  end)
  return b
end

function AB:OpenSimSettings()
  local model = ModelFor(self.current.class)
  if not model then self.Print("The simulator supports Warrior so far."); return end
  local f = self.simSettingsFrame
  if f and f:IsShown() then f:Hide(); return end
  if not f then f = self:CreateSimSettings(model) end
  f.Refresh()
  f:Show()
end

function AB:CreateSimSettings(model)
  local f = CreateFrame("Frame", "AshenBuildsSimSettings", UIParent); f:SetWidth(500); f:SetHeight(780)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  self:WindowBackdrop(f); self:SetupWindow(f); f:Hide(); self.simSettingsFrame = f
  self:ApplyEmberBackground(f, 10, 0.5, 0.5, 0.5); self:AddEmberHeader(f, 34)
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); title:SetPoint("TOP", f, "TOP", 0, -16); title:SetText("SIM SETTINGS - WARRIOR")
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
  local g = self.THEME.gold
  local function Header(text, x, y) local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); fs:SetPoint("TOPLEFT", f, "TOPLEFT", x, y); fs:SetText(text); fs:SetTextColor(Color(g)) end
  local controls = {}
  local function C() return model.GetSettings() end
  local function Changed() if AB.simPanel then AB:UpdateSimPanel() end end
  local function Num(label, x, y, key, lo, hi)
    table.insert(controls, NumberRow(f, label, x, y, function() return C()[key] end, function(v) C()[key] = math.max(lo, math.min(hi, v)); Changed() end))
  end

  Header("ENCOUNTER", 22, -48)
  -- Boss picker: fills in the boss's armor (typing an armor value switches back to Custom).
  local bl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); bl:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -68); bl:SetText("Boss")
  local boss = self:CreateDropdown(f, 176, {
    listWidth = 240,
    items = function()
      local out, k = {{value = "custom", text = "Custom armor"}}
      for k = 1, table.getn(model.BOSSES) do
        local b = model.BOSSES[k]
        table.insert(out, {value = b[1], text = b[1].."  |cff8d96a8"..b[2].."|r"})
      end
      return out
    end,
    getText = function() local b = C().boss; if not b or b == "custom" then return "Custom armor" end; return b end,
    isChecked = function(v) return (C().boss or "custom") == v end,
    onSelect = function(v)
      local st = C(); st.boss = v
      local k
      for k = 1, table.getn(model.BOSSES) do if model.BOSSES[k][1] == v then st.targetArmor = model.BOSSES[k][2]; st.targetLevel = 63 end end
      f.Refresh(); Changed()
    end})
  boss:SetPoint("TOPLEFT", f, "TOPLEFT", 52, -62)
  boss.Refresh = function() boss.text:SetText(boss.opts.getText()) end
  table.insert(controls, boss)
  Num("Fight length (sec)", 22, -96, "duration", 10, 900)
  Num("Target level", 22, -120, "targetLevel", 1, 63)
  Num("Target armor", 22, -144, "targetArmor", 0, 20000)
  do
    local armorBox = controls[table.getn(controls)]
    local commit = armorBox:GetScript("OnEnterPressed")
    local function Custom() local st = C(); local v = tonumber(armorBox:GetText()); if v and v ~= st.targetArmor then st.boss = "custom" end end
    armorBox:SetScript("OnEnterPressed", function() Custom(); commit(); f.Refresh() end)
  end
  Num("Number of targets", 22, -168, "targets", 1, 10)
  Num("Reaction time (ms)", 22, -192, "reaction", 0, 2000)
  Num("Execute phase (%)", 22, -216, "executePct", 0, 100)
  Num("Starting rage", 22, -240, "startRage", 0, 100)
  Num("Parry if in front (%)", 22, -264, "parry", 0, 50)
  local itNames = {}
  local i
  for i = 1, table.getn(ITERATIONS) do itNames[i] = tostring(ITERATIONS[i]) end
  table.insert(controls, CycleRow(f, "Position", 22, -290, {"behind", "front"}, {"Behind", "Front"}, function() return C().position end, function(v) C().position = v; Changed() end))
  table.insert(controls, CycleRow(f, "Iterations", 22, -316, ITERATIONS, itNames, function() return C().iterations end, function(v) C().iterations = v end))
  table.insert(controls, CycleRow(f, "Tanking", 22, -342, {"auto", "on", "off"}, {"Auto (shield)", "Boss hits you", "Off"}, function() return C().tanking end, function(v) C().tanking = v; Changed() end))
  Num("Boss swing speed (sec)", 22, -368, "bossSpeed", 0.5, 5)
  Num("Boss hit min (unmitigated)", 22, -392, "bossMin", 0, 20000)
  Num("Boss hit max (unmitigated)", 22, -416, "bossMax", 0, 20000)

  local ROT_Y = -142
  Header("ROTATION", 22, -322 + ROT_Y)
  local rv, rn = {}, {}
  for i = 1, table.getn(model.ROTATIONS) do rv[i] = model.ROTATIONS[i].key; rn[i] = model.ROTATIONS[i].name end
  local rot = CycleRow(f, "Preset", 22, -342 + ROT_Y, rv, rn, function() return C().rotation end, function(v) C().rotation = v; Changed() end)
  rot:SetWidth(150); table.insert(controls, rot)
  Num("Heroic Strike at rage", 22, -368 + ROT_Y, "hsRage", 0, 130)
  local function Check(label, x, y, get, set)
    local c = self:CreateCheck(f, label, function(on) set(on); Changed() end)
    c:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
    c.Refresh = function() c:SetChecked(get() and 1 or nil) end
    table.insert(controls, c)
    return c
  end
  Check("Use Heroic Strike / Cleave", 20, -390 + ROT_Y, function() return C().useHeroicStrike end, function(on) C().useHeroicStrike = on end)
  Check("Enrage from Bloodrage (reference)", 20, -410 + ROT_Y, function() return C().enrageOnBloodrage end, function(on) C().enrageOnBloodrage = on end)
  local rs = Check("New random fights each run", 258, -742, function() return C().randomSeed end, function(on) C().randomSeed = on end)
  rs:SetScript("OnEnter", function() GameTooltip:SetOwner(this, "ANCHOR_RIGHT"); GameTooltip:SetText("New random fights each run", 1, .82, 0)
    GameTooltip:AddLine("Off: every run replays the same fights, so the same build always gives the same DPS and a gear change shows its exact effect.", .9, .9, .9, 1)
    GameTooltip:AddLine("On: each run uses new fights and the number moves a little within its confidence range.", .9, .9, .9, 1); GameTooltip:Show() end)
  rs:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local ch = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); ch:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -438 + ROT_Y); ch:SetText("Abilities (ticking one switches to Custom):")
  for i = 1, table.getn(model.CUSTOM_ABILITIES) do
    local name = model.CUSTOM_ABILITIES[i]
    local col, row = math.mod(i - 1, 2), math.floor((i - 1) / 2)
    Check(name, 20 + col * 112, -452 + ROT_Y - row * 20, function() return C().custom[name] end, function(on)
      local s = C()
      -- Choosing abilities only means something for the Custom preset, so switch to it.
      if s.rotation ~= "custom" then
        s.rotation = "custom"
        -- Start the list from the abilities the automatic preset was using.
        local model2 = model
        local char = model2.BuildCharacter(AB.current, s)
        if char then
          s.custom = {}
          local auto = model2.ResolveRotation(char, {rotation = "auto"})
          local k
          for k = 1, table.getn(auto.normal) do s.custom[auto.normal[k]] = true end
        end
      end
      s.custom[name] = on or nil
      f.Refresh()
    end)
  end

  Header("BUFFS", 262, -48)
  for i = 1, table.getn(model.BUFFS) do
    local b = model.BUFFS[i]
    local c = Check(b.name, 258, -62 - (i - 1) * 21, function() return C().buffs[b.key] end, function(on)
      local s = C()
      if on and b.group then local j; for j = 1, table.getn(model.BUFFS) do if model.BUFFS[j].group == b.group then s.buffs[model.BUFFS[j].key] = nil end end end
      s.buffs[b.key] = on or nil
      f.Refresh()
    end)
    c.label:SetWidth(200); c.label:SetJustifyH("LEFT")
  end
  local dy = -62 - table.getn(model.BUFFS) * 21 - 10
  Header("TARGET DEBUFFS", 262, dy)
  for i = 1, table.getn(model.DEBUFFS) do
    local d = model.DEBUFFS[i]
    Check(d.name, 258, dy - 14 - (i - 1) * 21, function() return C().debuffs[d.key] end, function(on)
      local st = C()
      if on and d.group then local j; for j = 1, table.getn(model.DEBUFFS) do if model.DEBUFFS[j].group == d.group then st.debuffs[model.DEBUFFS[j].key] = nil end end end
      st.debuffs[d.key] = on or nil
      f.Refresh()
    end)
  end

  local reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); reset:SetWidth(120); reset:SetHeight(22)
  reset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 16); reset:SetText("Reset to defaults"); self:SkinQuietButton(reset)
  reset:SetScript("OnClick", function() AshenBuildsDB.simSettings.Warrior = nil; f.Refresh(); Changed() end)
  f.Refresh = function() local k; for k = 1, table.getn(controls) do controls[k].Refresh() end end
  return f
end

---------------------------------------------------------------------------
-- Hooks into the planner.
---------------------------------------------------------------------------
local oldCreateUI = AB.CreateUI
function AB:CreateUI()
  oldCreateUI(self)
  self:CreateSimPanel()
end

local oldRefresh = AB.RefreshUI
function AB:RefreshUI()
  oldRefresh(self)
  if self.simPanel then self:UpdateSimPanel() end
end

-- /ab sim runs the current build; /ab sim log prints one fight to the log window.
-- The planner registers /ab when it loads, so the sim commands are added at login.
local slashHook = CreateFrame("Frame")
slashHook:RegisterEvent("PLAYER_LOGIN")
slashHook:SetScript("OnEvent", function()
  local oldSlash = SlashCmdList and SlashCmdList["ASHENBUILDS"]
  if not oldSlash then return end
  SlashCmdList["ASHENBUILDS"] = function(msg)
    local cmd = string.lower(msg or "")
    if cmd == "sim" then if not AB.frame or not AB.frame:IsShown() then oldSlash("") end; AB:ToggleSim(); return end
    if cmd == "sim log" then AB:ShowSimLog(); return end
    if cmd == "sim settings" then AB:OpenSimSettings(); return end
    oldSlash(msg)
  end
end)
