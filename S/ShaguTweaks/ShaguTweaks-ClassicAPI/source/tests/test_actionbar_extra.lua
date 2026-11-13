local root = (arg[1] or ".") .. "/"
local env = setmetatable({}, { __index = getfenv(0) })
local modules, frames, casts = {}, {}, {}
local methods = {}
local saved = {}
local cursor, keydown, shift, tooltip, cooldownCalls, focus

local function NewFrame(kind, name, parent, template)
  local frame = setmetatable({ kind = kind, name = name, parent = parent, template = template,
    scripts = {}, events = {}, attributes = {}, shown = true }, { __index = methods })
  table.insert(frames, frame)
  if name then env[name] = frame end
  if template == "ActionButtonTemplate" then
    env[name .. "Icon"] = NewFrame("Texture", nil, frame)
    env[name .. "HotKey"] = NewFrame("FontString", nil, frame)
    env[name .. "Count"] = NewFrame("FontString", nil, frame)
    env[name .. "Cooldown"] = NewFrame("Model", nil, frame, "CooldownFrameTemplate")
    frame.normal = NewFrame("Texture", nil, frame)
  end
  return frame
end
function methods:GetName() return self.name end
function methods:GetFrameLevel() return self.level or 1 end
function methods:SetFrameLevel(level) self.level = level end
function methods:SetPoint(...) self.point = arg end
function methods:SetWidth(value) self.width = value end
function methods:SetHeight(value) self.height = value end
function methods:SetScript(key, value) self.scripts[key] = value end
function methods:RegisterEvent(key) self.events[key] = true end
function methods:UnregisterEvent(key) self.events[key] = nil end
function methods:SetAttribute(key, value) self.attributes[key] = value end
function methods:Click(button) table.insert(casts, { self.attributes.macro, button }) end
function methods:SetButtonState(value) self.buttonState = value end
function methods:GetEffectiveScale() return 1 end
function methods:Hide() self.shown = false end
function methods:Show() self.shown = true end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:CreateTexture() return NewFrame("Texture", nil, self) end
function methods:CreateFontString() return NewFrame("FontString", nil, self) end
function methods:SetText(text) self.text = text end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetNormalTexture(texture) self.normal.texture = texture end
function methods:GetNormalTexture() return self.normal end
function methods:GetTexture() return self.texture end
function methods:SetVertexColor(...) self.color = arg end
for _, name in ipairs({ "SetClampedToScreen", "SetHighlightTexture", "SetPushedTexture",
  "SetAllPoints", "SetFrameStrata", "RegisterForDrag", "RegisterForClicks", "EnableMouse", "SetChecked" }) do
  methods[name] = function() end
end

env.UIParent = NewFrame("Frame", "UIParent")
env.CreateFrame = NewFrame
env.ShaguTweaks = {
  T = setmetatable({}, { __index = function(_, key) return key end }),
  API = { IsShiftKeyDown = function() return shift end },
  GetGlobalEnv = function() return env end,
  register = function(_, module) modules[module.title] = module; return module end,
}
env.ShaguTweaks_config = saved
local updateGrid
env.ShaguTweaks.hooksecurefunc = function(name, callback)
  assert(name == "MultiActionBar_UpdateGridVisibility")
  updateGrid = callback
end
env.C_EventUtils = { IsEventValid = function() return true end }
env.GetCursorInfo = function() if cursor then return unpack(cursor) end end
env.CursorHasItem = function() end
env.CursorHasSpell = function() end
env.GetCursorMoney = function() return 0 end
env.ClearCursor = function() cursor = nil end
local nativeAction, rejectPlacement
env.ActionButton_ShowGrid = function(button)
  button.grid = (button.grid or 0) + 1
  button:Show()
end
env.ActionButton_HideGrid = function(button)
  button.grid = button.grid - 1
  assert(button.grid >= 0)
  if button.grid == 0 and not (button == env.ActionButton1 and nativeAction) then button:Hide() end
end
env.ActionButton_GetPagedID = function(button) assert(button == env.ActionButton1); return 73 end
env.GetActionInfo = function(slot) assert(slot == 73); if nativeAction then return unpack(nativeAction) end end
env.FindSpellBookSlotByID = function(id) if id == 456 then return 8, "spell" end end
env.PickupSpell = function(slot, book)
  assert(slot == 8 and book == "spell")
  cursor = { "spell", slot, book, 456 }
end
env.PlaceAction = function(slot)
  assert(slot == 73)
  if not rejectPlacement then nativeAction, cursor = { "spell", cursor[4] }, nil end
end
env.CastSpellByID = function(id) table.insert(casts, id) end
env.GetSpellInfo = function() return "Spell", nil, "spell-icon" end
env.IsUsableSpell = function() return 1 end
env.GetItemCooldown = function() return 1, 10, 1 end
env.GetMacroInfo = function(id) if id == 9 then return "My Macro", "macro-icon" end end
env.GetMacroIndexByName = function(name) if name == "My Macro" then return 9 else return 0 end end
env.GetBindingKey = function(binding) if binding == "STBAR6BUTTON1" then return "SHIFT-1" end end
env.GetBindingText = function(key) return key end
env.GetCVar = function() return keydown and "1" or "0" end
env.GetMouseFocus = function() return focus end
env.GetCursorPosition = function() return 10, 20 end
env.SpellIsTargeting = function() end
env.CooldownFrame_SetTimer = function() cooldownCalls = (cooldownCalls or 0) + 1 end
env.C_Spell = { GetSpellCooldown = function() return { startTime = 1, duration = 2, isEnabled = true } end }
env.C_Item = {
  UseItemByName = function(id) table.insert(casts, id) end,
  GetItemCount = function() return 4 end,
  GetItemIconByID = function() return "item-icon" end,
}
env.GameTooltip = {
  SetOwner = function() end, Show = function() end, Hide = function() end,
  SetSpellByID = function(_, id) tooltip = id end, SetItemByID = function(_, id) tooltip = id end,
}
local function Call(frame, script, button)
  env.this, env.arg1 = frame, button
  frame.scripts[script]()
  env.this, env.arg1 = nil, nil
end

local module = assert(loadfile(root .. "mods/actionbar-extra.lua"))
setfenv(module, env)
module()
assert(not modules["Action Bar 6"].enabled and not modules["Action Bar 7"].enabled)
assert(not env.ShaguTweaksExtraActionBar6 and not env.ShaguTweaksExtraActionBar7)
env.ShaguTweaks.ExtraActionButton(6, 1, "up")
assert(table.getn(casts) == 0)
local xml = assert(io.open(root .. "Bindings.xml", "r"))
local bindings = xml:read("*a")
xml:close()
for number = 6, 7 do
  assert(env["BINDING_HEADER_STBAR" .. number] == "Action Bar " .. number)
  for index = 1, 12 do
    assert(env["BINDING_NAME_STBAR" .. number .. "BUTTON" .. index])
    assert(string.find(bindings, 'name="STBAR' .. number .. 'BUTTON' .. index .. '"', 1, true))
    assert(string.find(bindings, "ExtraActionButton(" .. number .. ", " .. index .. ", keystate)", 1, true))
  end
end

modules["Action Bar 6"]:enable()
assert(not env.ShaguTweaksExtraActionBar7)
saved.ExtraActionBarSlots[7] = { [1] = { kind = "spell", id = 456 } }
modules["Action Bar 7"]:enable()
local horizontal, vertical = env.ShaguTweaksExtraActionBar6, env.ShaguTweaksExtraActionBar7
assert(horizontal.width > horizontal.height and vertical.height > vertical.width)
local a, b = env.ShaguTweaksExtraActionBar6Button1, env.ShaguTweaksExtraActionBar7Button1
assert(a.hotkey.text == "SHIFT-1" and b.icon.texture == "spell-icon")
assert(a.template == "ActionButtonTemplate" and not a.icon.shown and b.icon.shown)
assert(a.normal.color[4] == .5 and b.normal.color[4] == 1)
assert(a.cooldown.template == "CooldownFrameTemplate")
assert(not a:IsShown() and b:IsShown() and horizontal:IsShown())
env.ALWAYS_SHOW_MULTIBARS = "1"
updateGrid()
assert(a:IsShown() and b:IsShown())
env.ALWAYS_SHOW_MULTIBARS = 0
updateGrid()
assert(not a:IsShown() and b:IsShown())

cursor = { "spell", 3, "spell", 123 }
env.event = "CURSOR_CHANGED"
for _, frame in ipairs(frames) do
  if frame.events.CURSOR_CHANGED then Call(frame, "OnEvent") end
end
assert(a:IsShown())
Call(a, "OnReceiveDrag")
assert(not cursor and saved.ExtraActionBarSlots[6][1].id == 123)
assert(a:IsShown() and not env.ShaguTweaksExtraActionBar6Button2:IsShown())
assert(a.normal.color[4] == 1)
Call(a, "OnEnter")
assert(tooltip == 123)
env.ShaguTweaks.ExtraActionButton(6, 1, "down")
assert(table.getn(casts) == 0 and a.buttonState == "PUSHED")
env.ShaguTweaks.ExtraActionButton(6, 1, "up")
assert(casts[1] == 123 and a.buttonState == "NORMAL")
keydown = true
env.ShaguTweaks.ExtraActionButton(6, 1, "down")
env.ShaguTweaks.ExtraActionButton(6, 1, "up")
assert(casts[2] == 123 and table.getn(casts) == 2)

env.LOCK_ACTIONBAR = "1"
Call(a, "OnDragStart")
Call(b, "OnReceiveDrag")
assert(saved.ExtraActionBarSlots[6][1].id == 123)
shift = true
Call(a, "OnDragStart")
Call(a, "OnDragStop")
Call(b, "OnReceiveDrag")
assert(saved.ExtraActionBarSlots[6][1].id == 456 and saved.ExtraActionBarSlots[7][1].id == 123)
Call(a, "OnDragStart")
Call(a, "OnDragStop")
for _, frame in ipairs(frames) do
  if frame.kind == "Frame" and frame.events.PLAYER_ENTERING_WORLD and frame.scripts.OnUpdate then
    Call(frame, "OnUpdate")
  end
end
assert(saved.ExtraActionBarSlots[6][1].id == 456)
local c = env.ShaguTweaksExtraActionBar6Button2
assert(not c:IsShown())
focus = c
Call(a, "OnDragStart")
assert(c:IsShown())
Call(a, "OnDragStop")
Call(a, "OnClick", "LeftButton")
for _, frame in ipairs(frames) do
  if frame.events.PLAYER_ENTERING_WORLD and frame.scripts.OnUpdate then Call(frame, "OnUpdate") end
end
assert(not saved.ExtraActionBarSlots[6][1] and saved.ExtraActionBarSlots[6][2].id == 456)
assert(not a:IsShown() and c:IsShown())
Call(c, "OnDragStart")
Call(a, "OnReceiveDrag")
focus = NewFrame("CheckButton", "ActionButton1", env.UIParent)
local nativeTarget = focus
nativeTarget:Hide()
local existingGrid = NewFrame("CheckButton", "MultiBarBottomLeftButton1", env.UIParent)
existingGrid.grid = 1
local function DropOnNative()
  Call(a, "OnDragStart")
  assert(nativeTarget:IsVisible() and nativeTarget.grid == 1 and existingGrid.grid == 2)
  Call(a, "OnDragStart")
  assert(nativeTarget.grid == 1 and existingGrid.grid == 2)
  Call(a, "OnDragStop")
  for _, frame in ipairs(frames) do
    if frame.events.PLAYER_ENTERING_WORLD and frame.scripts.OnUpdate then Call(frame, "OnUpdate") end
  end
  assert(nativeTarget.grid == 0 and existingGrid.grid == 1 and existingGrid:IsVisible())
end
rejectPlacement = true
DropOnNative()
assert(not nativeAction and not cursor and saved.ExtraActionBarSlots[6][1].id == 456)
assert(not nativeTarget:IsVisible())
rejectPlacement = false
DropOnNative()
assert(nativeAction[2] == 456 and not cursor and not saved.ExtraActionBarSlots[6][1])
assert(nativeTarget:IsVisible())
cursor = { "spell", 8, "spell", 456 }
Call(a, "OnReceiveDrag")
Call(a, "OnClick", "RightButton")
assert(not saved.ExtraActionBarSlots[6][1])
assert(a.normal.color[4] == .5)
shift = false

cursor = { "item", 888 }
Call(a, "OnClick", "LeftButton")
assert(not cursor and a.count.text == 4 and table.getn(casts) == 2)
Call(a, "OnClick", "LeftButton")
assert(casts[3] == 888)
cursor = { "macro", 9 }
Call(a, "OnReceiveDrag")
assert(not cursor and a.icon.texture == "macro-icon")
Call(a, "OnClick", "RightButton")
assert(casts[4][1] == 9 and casts[4][2] == "RightButton")
cursor = { "money", 20 }
Call(a, "OnClick", "LeftButton")
assert(cursor and table.getn(casts) == 4)
horizontal:Hide()
env.ShaguTweaks.ExtraActionButton(6, 1, "down")
assert(table.getn(casts) == 4)
assert(cooldownCalls > 0)
print("Extra action bars: opt-in layouts, saved actions, mouse/key dispatch, cooldowns, drag/drop, cancel and clear passed")
