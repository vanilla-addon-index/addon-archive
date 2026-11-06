-- Pure Lua mocked Vanilla API integration tests; not an in-client render.
table.getn = table.getn or function(t) return #t end
SlashCmdList = {}
local chatLog = {}
DEFAULT_CHAT_FRAME = {AddMessage=function(self, s) table.insert(chatLog,s) end}
function UnitName() return 'Tester' end
local t = 123
function GetTime() return t end
local cid=4
function GetChannelName(name)
  if name=='World' then return cid, 'World' end
  return 0, nil
end
ChatTypeInfo={}
for i=1,10 do ChatTypeInfo['CHANNEL'..i]={r=0.7,g=0.3,b=0.2} end
local old={r=0.7,g=0.3,b=0.2}
local function colorEq(info,r,g,b)
  return math.abs(info.r-r)<0.00001 and math.abs(info.g-g)<0.00001 and math.abs(info.b-b)<0.00001
end
local delivered=0
function ChatFrame_OnEvent() delivered=delivered+1 end
local menuEntries={}
local menuInitialize
function UIDropDownMenu_Initialize(frame, fn, init) menuInitialize=fn end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton(info, level) table.insert(menuEntries,{level=level,info=info}) end
function CloseDropDownMenus() end
function ToggleDropDownMenu() end
function getglobal(name) return _G[name] end
UIParent = {}
local Frame={}
Frame.__index=Frame
function Frame:RegisterEvent() end
function Frame:SetScript() end
function Frame:SetWidth() end
function Frame:SetHeight() end
function Frame:SetPoint() end
function Frame:GetName() return self.name end
function CreateFrame(type,name,parent,template) return setmetatable({name=name},Frame) end

ColorPickerFrame = {
  r=0,g=0,b=0, hasOpacity=false,
  SetColorRGB=function(self,r,g,b)
    self.r,self.g,self.b=r,g,b
    if self.func then self.func() end
  end,
  GetColorRGB=function(self) return self.r,self.g,self.b end,
  Hide=function(self) self.visible=false end,
  Show=function(self) self.visible=true end,
}
local root=''
WorldChatFilterDB = {enabled=true, tintWorld=true, sensitivity='balanced', minimapAngle=235}
for _,file in ipairs({'Core.lua','Color.lua','Statistics.lua','Classifier.lua','Filter.lua','UI.lua'}) do
  assert(loadfile(root..file), 'Lua parse '..file)
  dofile(root..file)
end
local W = WorldChatFilter
W.Initialize()
assert(W.VERSION == '1.1.2')
assert(W.db.minimapAngle == 235)
assert(W.GetWorldColorPreset() == 'gold')
assert(W.GetWorldColorHex() == '#D1B77F')
assert(#W.COLOR_PRESETS == 4)
-- Core original color and World-only safeguard
W.RefreshWorldColor()
assert(colorEq(ChatTypeInfo.CHANNEL4,209/255,183/255,127/255))
assert(colorEq(ChatTypeInfo.CHANNEL2,old.r,old.g,old.b))
-- Preset change live
assert(W.SelectWorldColorPreset('sage'))
assert(W.GetWorldColorHex()=='#A9BDA5')
assert(colorEq(ChatTypeInfo.CHANNEL4,169/255,189/255,165/255))
assert(not W.SelectWorldColorPreset('invalid'))
assert(W.GetWorldColorPreset()=='sage')
-- Picker custom live changes + cancel returns prior preset and tint
assert(W.OpenWorldColorPicker())
assert(ColorPickerFrame.visible)
assert(ColorPickerFrame.hasOpacity==false)
ColorPickerFrame:SetColorRGB(0.13,0.56,0.77)
assert(W.GetWorldColorPreset()=='custom')
assert(colorEq(ChatTypeInfo.CHANNEL4,0.13,0.56,0.77))
local count=delivered
ColorPickerFrame.cancelFunc(ColorPickerFrame.previousValues)
assert(W.GetWorldColorPreset()=='sage')
assert(colorEq(ChatTypeInfo.CHANNEL4,169/255,189/255,165/255))
assert(delivered==count)
-- Commit custom across relog, reopen picker, cancel restores saved custom RGB
assert(W.OpenWorldColorPicker())
ColorPickerFrame:SetColorRGB(0.9,0.5,0.2)
assert(W.GetWorldColorHex()=='#E68033')
local db=WorldChatFilterDB
W.db=nil;W.Initialize()
assert(W.db==db and W.GetWorldColorPreset()=='custom')
assert(W.GetWorldColorHex()=='#E68033')
assert(colorEq(ChatTypeInfo.CHANNEL4,0.9,0.5,0.2))
assert(W.OpenWorldColorPicker())
ColorPickerFrame:SetColorRGB(0.2,0.2,0.2)
ColorPickerFrame.cancelFunc()
assert(W.GetWorldColorHex()=='#E68033')
-- Change World's channel number; former slot restores and new tint only on World.
cid=5;W.RefreshWorldColor()
assert(colorEq(ChatTypeInfo.CHANNEL4,old.r,old.g,old.b))
assert(colorEq(ChatTypeInfo.CHANNEL5,0.9,0.5,0.2))
assert(colorEq(ChatTypeInfo.CHANNEL2,old.r,old.g,old.b))
-- Disabling tint and filter always restore original World color
W.db.tintWorld=false;W.RefreshWorldColor()
assert(colorEq(ChatTypeInfo.CHANNEL5,old.r,old.g,old.b))
W.db.tintWorld=true;W.RefreshWorldColor()
assert(colorEq(ChatTypeInfo.CHANNEL5,0.9,0.5,0.2))
W.db.enabled=false;W.RefreshWorldColor()
assert(colorEq(ChatTypeInfo.CHANNEL5,old.r,old.g,old.b))
W.db.enabled=true;W.RefreshWorldColor()
assert(colorEq(ChatTypeInfo.CHANNEL5,0.9,0.5,0.2))
-- Changing color with tint disabled must not recolor World prematurely
W.db.tintWorld=false;W.RefreshWorldColor()
W.SelectWorldColorPreset('lavender')
assert(colorEq(ChatTypeInfo.CHANNEL5,old.r,old.g,old.b))
W.db.tintWorld=true;W.RefreshWorldColor()
assert(colorEq(ChatTypeInfo.CHANNEL5,184/255,169/255,206/255))
W.ResetWorldColorSelection()
assert(W.GetWorldColorHex()=='#D1B77F')
assert(colorEq(ChatTypeInfo.CHANNEL5,209/255,183/255,127/255))
-- Category classifier unchanged; same ad in Trade bypasses and cannot recolor.
local ad='LFM1 dd (no rogue) DMW'
local _,_,_,block=W.ClassifyMessage(ad)
assert(block)
local oldStats=W.GetStats().total
t=t+1;arg1=ad;arg2='PlayerX';arg4='5. World';arg7=17;arg8=5;arg9='World'
local baseline=delivered
ChatFrame_OnEvent('CHAT_MSG_CHANNEL')
assert(delivered==baseline)
assert(W.GetStats().total == oldStats+1)
t=t+1;arg1=ad;arg2='PlayerX';arg4='2. Trade';arg7=0;arg8=2;arg9='Trade'
ChatFrame_OnEvent('CHAT_MSG_CHANNEL')
assert(delivered==baseline+1)
assert(W.GetStats().total == oldStats+1)
assert(colorEq(ChatTypeInfo.CHANNEL2,old.r,old.g,old.b))
-- dropdown menu submenus and invoking actual callbacks
W.BuildUI()
assert(menuInitialize)
local function menuFind(level,group,target)
  menuEntries={}; UIDROPDOWNMENU_MENU_VALUE=group
  menuInitialize(nil,level)
  for _,entry in ipairs(menuEntries) do
    if entry.info.text==target then return entry.info end
  end
  error('Missing menu entry '..tostring(target)..' at level '..tostring(level))
end
local rootEntry=menuFind(1,nil,'World Chat Color')
assert(rootEntry.hasArrow and rootEntry.value=='worldColor')
local presetMenu=menuFind(2,'worldColor','Color Presets')
assert(presetMenu.hasArrow and presetMenu.value=='colorPresets')
local gold=menuFind(3,'colorPresets','Dusty Gold')
assert(type(gold.func)=='function')
assert(gold.hasColorSwatch==1 and math.abs(gold.r-209/255)<0.00001)
assert(type(gold.swatchFunc)=='function')
gold.func()
assert(W.GetWorldColorHex()=='#D1B77F')
assert(colorEq(ChatTypeInfo.CHANNEL5,209/255,183/255,127/255))
local custom=menuFind(2,'worldColor','Choose Custom Color...')
custom.func()
ColorPickerFrame:SetColorRGB(0.22,0.88,0.3)
assert(W.GetWorldColorPreset()=='custom')
local reset=menuFind(2,'worldColor','Reset to Dusty Gold')
reset.func()
assert(W.GetWorldColorHex()=='#D1B77F')
local toggle=menuFind(2,'worldColor','Enable Custom World Color')
toggle.func()
assert(W.db.tintWorld==false)
assert(colorEq(ChatTypeInfo.CHANNEL5,old.r,old.g,old.b))
assert(colorEq(ChatTypeInfo.CHANNEL2,old.r,old.g,old.b))
-- color on/off slash command
SlashCmdList.WORLDCHATFILTER('color on')
assert(W.db.tintWorld and colorEq(ChatTypeInfo.CHANNEL5,209/255,183/255,127/255))
SlashCmdList.WORLDCHATFILTER('color off')
assert(not W.db.tintWorld and colorEq(ChatTypeInfo.CHANNEL5,old.r,old.g,old.b))
print('PASS - version, presets, saved color, cancel, live tint, no opacity, submenu/UI, slash, World isolation, Trade untouched')
