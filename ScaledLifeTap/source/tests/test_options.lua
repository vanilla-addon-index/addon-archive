-- usage (from the repository root): lua5.0 tests/test_options.lua .
-- Tests the options page in ClassicAPI's AddOn Options window and standalone,
-- and the mana check through ClassicAPI's combat log.
local SLTDIR = arg[1] or "."
local fails = 0
local function check(name, cond, extra)
  print((cond and "PASS " or "FAIL ") .. name .. (extra and ("  " .. extra) or ""))
  if not cond then fails = fails + 1 end
end

local clock = 0
local function boot(withClassicAPI)
  dofile("tests/mockwow.lua")
  function GetTime() return clock end
  MOCK.gear = MOCK.SAMPLE_GEAR
  MOCK.spellbook = { {"Life Tap","Rank 1"}, {"Life Tap","Rank 2"}, {"Life Tap","Rank 3"}, {"Life Tap","Rank 4"}, {"Life Tap","Rank 5"}, {"Life Tap","Rank 6"} }
  MOCK.categories = {}
  if withClassicAPI then
    -- the parts of ClassicAPI the addon uses
    function InterfaceOptions_AddCategory(panel) table.insert(MOCK.categories, panel); panel:Hide() end
    function InterfaceOptionsFrame_OpenToCategory(panel) MOCK.opened = panel; panel:Show() end
    function GetSpellBonusDamage(school) return school == 6 and 650 or 0 end
    function UnitGUID(unit) return unit == "player" and "0xPLAYER" or "0xOTHER" end
    MOCK.timers = {}
    C_Timer = { After = function(sec, fn) table.insert(MOCK.timers, fn) end }
    MOCK.cl = nil
    function CombatLogGetCurrentEventInfo() if MOCK.cl then return unpack(MOCK.cl) end end
  else
    InterfaceOptions_AddCategory, InterfaceOptionsFrame_OpenToCategory, GetSpellBonusDamage = nil, nil, nil
    UnitGUID, C_Timer, CombatLogGetCurrentEventInfo = nil, nil, nil
  end
  GetNampowerVersion, GetSpellPower = nil, nil
  SLT_Config = nil
  for _, f in ipairs({"Locale.lua", "Scanner.lua", "ScaledLifeTap.lua", "Options.lua"}) do dofile(SLTDIR .. "/" .. f) end
  MOCK.fire("VARIABLES_LOADED"); MOCK.fire("PLAYER_ENTERING_WORLD"); MOCK.fire("SPELLS_CHANGED")
end

local function findControl(page, template, index)
  local n = 0
  for _, c in ipairs(page.controls) do
    if c.template == template then n = n + 1; if n == index then return c end end
  end
end
local function click(check) this = check; check.checked = (not check.checked) and 1 or nil; check.scripts.OnClick() end
local function slide(slider, v) slider:SetValue(v) end

---------------------------------------------------------------------------
print("-- with ClassicAPI")
boot(true)
local main, ranks = ScaledLifeTap.OptionsPage, ScaledLifeTap.RanksPage
check("two pages registered in AddOn Options", table.getn(MOCK.categories) == 2 and MOCK.categories[1] == main and MOCK.categories[2] == ranks)
check("main page named ScaledLifeTap, ranks page under it", main.name == "ScaledLifeTap" and ranks.parent == "ScaledLifeTap")
SlashCmdList["SCALEDLIFETAP"]("options")
check("/slt options opens ClassicAPI window at our page", MOCK.opened == main)

main.refresh()
local overtap = findControl(main, "OptionsCheckButtonTemplate", 1)
local calibrate = findControl(main, "OptionsCheckButtonTemplate", 2)
local debug = findControl(main, "OptionsCheckButtonTemplate", 3)
local reserve = findControl(main, "OptionsSliderTemplate", 1)
local bonus = findControl(main, "OptionsSliderTemplate", 2)
local source = findControl(main, "UIDropDownMenuTemplate", 1)
check("controls show saved values", overtap.checked == 1 and calibrate.checked == 1 and debug.checked == nil and reserve.value == 0)
check("mana check enabled (ClassicAPI combat log available)", calibrate.enabled)

click(overtap); slide(reserve, 23); click(debug)
check("changes apply at once", SLT_Config.overtap == false and SLT_Config.reserve == 25 and SLT_Config.debug == true,
  string.format("overtap=%s reserve=%s debug=%s", tostring(SLT_Config.overtap), tostring(SLT_Config.reserve), tostring(SLT_Config.debug)))
main.cancel()
check("Cancel restores the values from when the page opened", SLT_Config.overtap == true and SLT_Config.reserve == 0 and SLT_Config.debug == false)

main.refresh(); slide(reserve, 40); main.okay(); main.cancel()
check("Okay keeps changes (a later Cancel does nothing)", SLT_Config.reserve == 40)
main.default()
check("Defaults restores defaults", SLT_Config.reserve == 0 and SLT_Config.overtap == true and SLT_Config.source == "auto")

-- source dropdown
main.refresh()
local texts = {}
for _, info in ipairs(MOCK.dropdownItems) do texts[info.value] = info.text end
check("dropdown lists sources, marks missing ones", texts.auto == "Automatic" and texts.classicapi == "ClassicAPI"
  and texts.nampower == "Nampower (not running)" and texts.internal == "built-in scanner", texts.nampower)
for _, info in ipairs(MOCK.dropdownItems) do if info.value == "internal" then this = info; info.func() end end
check("picking a source saves it", SLT_Config.source == "internal")
local total, _, _, src = ScaledLifeTap_GetDamageBonus()
check("forced built-in source used", src == "built-in scanner" and total == 518)
SLT_Config.source = "auto"; main.refresh()

-- extra spell damage greyed out while a live source is in use
check("extra spell damage label greyed with ClassicAPI", getglobal(bonus:GetName() .. "Text").color[1] == GRAY_FONT_COLOR.r)

-- status text
local summaryText
for _, f in ipairs(MOCK.frames) do end
main.OnRefresh()
local found = false
local lines = ScaledLifeTap.StatusLines()
check("summary mentions ClassicAPI and incl. buffs", string.find(lines[1], "ClassicAPI", 1, true) and string.find(lines[1], "incl. buffs", 1, true), lines[1])
local _, rankLines = ScaledLifeTap.StatusLines()
check("ranks page lists 6 ranks", table.getn(rankLines) == 6 and rankLines[1] == "Rank 6: -944 health, +1132 mana", rankLines[1])

-- mana check through ClassicAPI's combat log (no Nampower)
SLT_Config.calibrate = true; ScaledLifeTap.ResetCalibration()
local clFrame
for i = 1, 12 do
  MOCK.hp, MOCK.mana, MOCK.casts = 3500, 1000, {}
  MOCK.timers = {}
  ScaledLifeTap_CastLifeTap()
  clFrame = nil
  for _, f in ipairs(MOCK.frames) do if f.events["COMBAT_LOG_EVENT_UNFILTERED"] then clFrame = f end end
  if i == 1 then check("combat log registered only after a tap", clFrame ~= nil and table.getn(MOCK.timers) == 1) end
  -- someone else's Life Tap first: ignored
  MOCK.cl = { 1, "SPELL_ENERGIZE", false, "0xOTHER", "Bob", 0, 0, "0xOTHER", "Bob", 0, 0, 11689, "Life Tap", 32, 999, 0 }
  this, event = clFrame, "COMBAT_LOG_EVENT_UNFILTERED"; clFrame.scripts.OnEvent()
  -- then ours, at 90% of predicted
  MOCK.cl = { 1, "SPELL_ENERGIZE", false, "0xPLAYER", "Me", 0, 0, "0xPLAYER", "Me", 0, 0, 11689, "Life Tap", 32, 1132.8 * 0.9, 0 }
  clFrame.scripts.OnEvent()
  clock = clock + 5
end
check("combat log mana check learns 0.90", math.abs(SLT_Config.gainFactor - 0.9) < 0.01, string.format("%.3f", SLT_Config.gainFactor))
check("combat log unregistered after the energize", not clFrame.events["COMBAT_LOG_EVENT_UNFILTERED"])
-- timeout path: cast, no energize, timer fires
MOCK.timers = {}; MOCK.mana = 1000; ScaledLifeTap_CastLifeTap()
check("registered again on next tap", clFrame.events["COMBAT_LOG_EVENT_UNFILTERED"] == true)
MOCK.timers[1]()
check("timer unregisters if no energize arrives", not clFrame.events["COMBAT_LOG_EVENT_UNFILTERED"])
SLT_Config.calibrate = false; MOCK.mana = 1000; ScaledLifeTap_CastLifeTap()
check("mana check off: combat log not registered", not clFrame.events["COMBAT_LOG_EVENT_UNFILTERED"])

---------------------------------------------------------------------------
print("-- without ClassicAPI (standalone window)")
boot(false)
main = ScaledLifeTap.OptionsPage
check("no categories registered", table.getn(MOCK.categories) == 0)
SlashCmdList["SCALEDLIFETAP"]("options")
local win = ScaledLifeTapOptionsWindow
check("/slt options opens standalone window", win and win:IsShown() and main.parentFrame == win)
check("Escape closes it (in UISpecialFrames)", UISpecialFrames[1] == "ScaledLifeTapOptionsWindow")
calibrate = findControl(main, "OptionsCheckButtonTemplate", 2)
bonus = findControl(main, "OptionsSliderTemplate", 2)
check("mana check greyed out without Nampower/ClassicAPI", calibrate.enabled == false)
check("extra spell damage active with built-in scanner", getglobal(bonus:GetName() .. "Text").color[1] == NORMAL_FONT_COLOR.r)
slide(bonus, 42)
check("bonus slider snaps to step 5 and saves", SLT_Config.bonus == 40, tostring(SLT_Config.bonus))
SlashCmdList["SCALEDLIFETAP"]("options")
check("/slt options again closes it", not win:IsShown())

print(fails == 0 and "ALL TESTS PASSED" or (fails .. " FAILED"))
