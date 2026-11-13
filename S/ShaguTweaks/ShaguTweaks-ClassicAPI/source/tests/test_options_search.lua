local root=(arg[1] or '.') .. '/'
local function noop() end
local methods={}
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:SetText(v) self.text=v; if self.scripts.OnTextChanged then local old=this; this=self; self.scripts.OnTextChanged(); this=old end end
function methods:GetText() return self.text or '' end
function methods:Show() self.visible=true end
function methods:Hide() self.visible=false end
function methods:IsShown() return self.visible end
function methods:SetWidth(v) self.width=v end
function methods:SetHeight(v) self.height=v end
function methods:SetPoint(...) self.point=arg end
function methods:GetWidth() return self.width or 500 end
function methods:GetHeight() return self.height or 900 end
function methods:GetScale() return 1 end
function methods:GetFrameLevel() return 1 end
function methods:SetFocus() self.focused=true end
function methods:ClearFocus() self.focused=false end
function methods:HighlightText() self.selected=true end
function methods:SetVertexColor(r,g,b,a) self.color={r,g,b,a} end
function methods:SetChecked(v) self.checked=v end
function methods:GetChecked() return self.checked end
function methods:Enable() self.enabled=true end
function methods:Disable() self.enabled=false end
function methods:SetValue(v) self.value=v; if self.scripts.OnValueChanged then local old=this; this=self; self.scripts.OnValueChanged(); this=old end end
function methods:GetValue() return self.value end
function methods:CreateFontString() return CreateFrame() end
function methods:CreateTexture() return CreateFrame() end
local made=0
function CreateFrame(kind,name,parent,template)
 made=made+1
 local f=setmetatable({scripts={},visible=true},{__index=function(t,k) if methods[k] then return methods[k] elseif string.find(k,'^[A-Z]') then return noop end end})
 if name then _G[name]=f end
 if name and template=='OptionsCheckButtonTemplate' then _G[name..'Text']=CreateFrame() end
 if name and template=='UIDropDownMenuTemplate' then
  for _,suffix in ipairs({'Left','Middle','Right'}) do _G[name..suffix]=CreateFrame() end
 end
 return f
end
UIParent=CreateFrame(); GameMenuFrame=CreateFrame(); GameMenuButtonUIOptions=CreateFrame(); GameMenuButtonKeybindings=CreateFrame(); GameTooltip=CreateFrame()
UISpecialFrames={}; DEFAULTS='Defaults'; OKAY='Okay'; CANCEL='Cancel'; CLOSE='Close'
ShowUIPanel=noop; HideUIPanel=noop; UpdateMicroButtons=noop
local reloaded=false
function ReloadUI() reloaded=true end
Minimap=CreateFrame()
ShaguTweaks={T=setmetatable({},{__index=function(t,k) return k end}),mods={}}
function ShaguTweaks.GetGlobalEnv() return _G end
function ShaguTweaks:GetExpansion() return 'vanilla' end
function ShaguTweaks.spairs(t,comp)
 local keys={}; for k in pairs(t) do table.insert(keys,k) end; table.sort(keys,comp)
 local i=0; return function() i=i+1; if keys[i] then return keys[i],t[keys[i]] end end
end
local function add(title,category,description,sliders)
 ShaguTweaks.mods[title]={title=title,category=category,description=description,sliders=sliders,expansions={vanilla=true}}
end
add('Golden UI','Interface','Colors borders gold')
add('Darkened UI','Interface','Darkens borders')
add('Other Interface','Interface','Another interface feature')
add('Hide Player Frame Resources','Unit Frames','Hides native resources')
add('Hide Player Name','Unit Frames','Hides native name')
ShaguTweaks.mods['Hide Player Name'].requires={'Hide Player Frame Resources'}
add('Item Rarity Borders','Tooltip & Items','Colors mail and trade items')
add('Range Color','Action Bar','Shows distance',{{key='range.delay',label='Update interval',min=1,max=10,default=3}})
for i=1,40 do add('Other '..i,'Other','Another feature') end
ShaguTweaks_config={overwrites={}}
GetAddOnMetadata=function(addon,key) assert(addon=='ShaguTweaks' and key=='Version');return '3.8.5' end
local menu={}
function UIDropDownMenu_Initialize(dropdown,callback) dropdown.initialize=callback end
function UIDropDownMenu_SetWidth(width,dropdown) dropdown.width=width end
function UIDropDownMenu_SetSelectedID(dropdown,id) dropdown.selected=id end
function UIDropDownMenu_SetText(text,dropdown) dropdown.text=text end
function UIDropDownMenu_AddButton(info) table.insert(menu,info) end
local function choose(dropdown,id)
 menu={};dropdown.initialize();assert(table.getn(menu)==3);menu[id].func()
end
dofile(root..'config.lua')
local gui=AdvancedSettingsGUI
assert(gui.version:GetText()=='v3.8.5')
this=gui.version;gui.version.scripts.OnClick();this=nil
assert(gui.projectLink.visible and gui.projectLink.edit.focused and gui.projectLink.edit.selected)
assert(gui.projectLink.edit:GetText()=='https://octowow.st/git/OEVG/ShaguTweaks-ClassicAPI')
gui.projectLink.close.scripts.OnClick();assert(not gui.projectLink.visible)
this=gui; gui.scripts.OnShow(); this=nil
assert(gui.scrollframe.visible)
local hideName=gui.entries['Hide Player Name']
local hideResources=gui.entries['Hide Player Frame Resources']
assert(not hideName.enabled)
hideName:SetChecked(true);this=hideName;hideName.scripts.OnClick();assert(not hideName.checked)
hideResources:SetChecked(true);this=hideResources;hideResources.scripts.OnClick();assert(hideName.enabled)
hideName:SetChecked(true);this=hideName;hideName.scripts.OnClick()
gui.search:SetText('Hide Player Name');assert(hideName.enabled and hideName.checked)
gui.search:SetText('')
hideResources:SetChecked(false);this=hideResources;hideResources.scripts.OnClick()
assert(not hideName.enabled and hideName.checked) -- retain dependent choice while dormant
local firstCount=made
local checkbox=gui.entries['ui-mode'];local dropdown=gui.modeDropdown
assert(checkbox.point[2]==gui and checkbox.point[5]==-56)
assert(not gui.entries['Golden UI'] and not gui.entries['Darkened UI'])
assert(dropdown.selected==1)
choose(dropdown,2);assert(dropdown.text=='Darkened')
choose(dropdown,3);assert(dropdown.text=='Golden')
-- Collapse a category before searching: matches must still be visible.
local collapse=gui.category.Interface.button; this=collapse; collapse.scripts.OnClick(); this=nil
assert(checkbox.visible and not gui.entries['Other Interface'].visible)
gui.search:SetText('  GOLDEN  ')
assert(checkbox.visible and dropdown.selected==3 and not gui.entries['Range Color'].visible)
assert(not gui.scrollframe.visible and not gui.empty.visible)
assert(not ShaguTweaks_config['Golden UI'])
gui.search:SetText('mail'); assert(gui.entries['Item Rarity Borders'].visible and checkbox.visible)
gui.search:SetText('update interval'); assert(gui.entries['Range Color'].visible and gui.entries['slider:range.delay'].visible)
gui.search:SetText('[.*'); assert(gui.empty.visible) -- literal, not Lua pattern matching
this=gui.searchClear; gui.searchClear.scripts.OnClick(); this=nil
assert(not gui.empty.visible and checkbox.visible and dropdown.selected==3 and gui.scrollframe.visible)
assert(made==firstCount) -- subsequent searches reuse all widgets
this=gui.okay; gui.okay.scripts.OnClick(); this=nil
assert(ShaguTweaks_config['Golden UI']==1 and ShaguTweaks_config['Darkened UI']==0 and reloaded)
-- Defaults and Cancel change only the temporary selection.
this=gui;gui.scripts.OnShow();this=nil
gui:defaults();assert(dropdown.selected==1 and ShaguTweaks_config['Golden UI']==1)
this=gui.cancel;gui.cancel.scripts.OnClick();this=nil
this=gui;gui.scripts.OnShow();this=nil;assert(dropdown.selected==3)
ShaguTweaks_config['Darkened UI']=1
this=gui;gui.scripts.OnShow();this=nil;assert(dropdown.selected==2)
assert(ShaguTweaks_config['Golden UI']==1) -- opening does not alter saved config
choose(dropdown,1);this=gui.okay;gui.okay.scripts.OnClick();this=nil
assert(ShaguTweaks_config['Golden UI']==0 and ShaguTweaks_config['Darkened UI']==0)
for _,color in ipairs({{r=.3,g=.3,b=.3},{r=.8,g=.62,b=.32}}) do
 ShaguTweaks.UIBorder=color;gui:load()
 for _,suffix in ipairs({'Left','Middle','Right'}) do
  local c=_G['AdvancedSettingsGUIUIMode'..suffix].color
  assert(c[1]==color.r and c[2]==color.g and c[3]==color.b and c[4]==1)
 end
end
print('Search: literal/case-insensitive matching, descriptions/sliders, collapsed categories, empty/clear, widget reuse, scroll layouts and unsaved settings passed')
