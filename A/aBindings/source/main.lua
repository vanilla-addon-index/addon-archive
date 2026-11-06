
aBindings = {
  b = {},
  debug = false,
}

local function debug(msg, ...)
  if not aBindings.debug then return end
  DEFAULT_CHAT_FRAME:AddMessage(date('%X aBindings: ') .. string.format(msg, unpack(arg)))
end

local ebox = CreateFrame('EditBox', 'aBindingsEditBox')
ebox:SetAutoFocus(false)
ebox:ClearFocus()
ebox.chatFrame = DEFAULT_CHAT_FRAME
ebox:Hide()

local function OnClick()
  debug('Button %s clicked', this:GetName())
  for line in string.gfind(this.macrotext, '[^\n]+') do
    debug('Parsing line: %s', line)
    line = string.gsub(line, '^%s*', '', 1)
    ebox:SetText(line)
    ChatEdit_ParseText(ebox, 1)
  end
end

ebox:SetScript('OnEvent', function()
  local btnidx = 0
  for key, macrotext in next, (aBindings.b) do
    btnidx = btnidx + 1
    local bname = 'aBindings' .. btnidx
    local btn = CreateFrame('Button', bname)
    btn:SetScript('OnClick', OnClick)
    btn.macrotext = macrotext
    local macro = string.upper(bname)
    SetBinding(key, macro)
    debug('Set up macrotext binding for key %q on button %q to macro %q:\n%s', key, bname, macro, macrotext)
  end
  debug('aBindings loaded. Bindings found: %d', btnidx)
  this:SetScript('OnEvent', nil)
  this:UnregisterEvent('PLAYER_ENTERING_WORLD')
end)
ebox:RegisterEvent('PLAYER_ENTERING_WORLD')

