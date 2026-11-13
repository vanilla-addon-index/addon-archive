local f=assert(io.open((arg[1] or '.') .. '/mods/dark-ui-elements.lua','r'))
local source=f:read('*a'); f:close(); assert(loadstring(source))
local first=assert(string.find(source,'local ADDON_PREFIXES =',1,true))
local last=assert(string.find(source,'local function LockTextureBorder',first,true))
edge={r=.8,g=.62,b=.32}
local names,lock=assert(loadstring(string.sub(source,first,last-1)..'return {IsAddonFrameName, LockBorder}'))()
local matches=names[1]; local lock=names[2]
assert(matches('MailAttachment1')); assert(matches('MailAttachment21')); assert(matches('SendMailPackageButton')); assert(matches('aux_frame')); assert(matches('aux_frameBorder')); assert(matches('AuxCraftWindow')); assert(matches('AuxCraftDragOutline')); assert(matches('AuxDragOutline')); assert(not matches('UnrelatedWindow'))
local frame={r=.6,g=.6,b=.6,a=1}
function frame:SetBackdropBorderColor(r,g,b,a) self.r,self.g,self.b,self.a=r,g,b,a end
function frame:GetBackdropBorderColor() return self.r,self.g,self.b,self.a end
function frame:SetBackdrop(b) self.backdrop=b end
lock(frame); assert(frame.r==edge.r and frame.g==edge.g and frame.b==edge.b)
frame:SetBackdropBorderColor(0,1,0,1); assert(frame.r==0 and frame.g==1 and frame.b==0)
frame:SetBackdrop({edgeFile='border'}); assert(frame.r==edge.r)
frame:SetBackdropBorderColor(.6,.6,.6,.5); assert(frame.r==edge.r and frame.a==.5)
print('Lua 5.0: syntax, aux/AuxCraft recognition, palette persistence and quality colors passed')
-- Preserve an item's exact rarity color, including common white and alpha,
-- when another addon reapplies its backdrop after our palette hook.
frame.stPreserveRarityColor=true
frame:SetBackdropBorderColor(1,1,1,.8)
frame:SetBackdrop({edgeFile='replacement'})
assert(frame.r==1 and frame.g==1 and frame.b==1 and frame.a==.8)
frame:SetBackdropBorderColor(0,1,0,.6)
frame:SetBackdrop({edgeFile='replacement'})
assert(frame.r==0 and frame.g==1 and frame.b==0 and frame.a==.6)
print('Rarity preservation across backdrop resets passed')
-- Loading the palette module with both options disabled must not install
-- border hooks, create frames, or alter TrinketMenu's own gray frame border.
local paletteModules={}
ShaguTweaks={T=setmetatable({},{__index=function(t,k) return k end})}
function ShaguTweaks.GetGlobalEnv() return _G end
function ShaguTweaks.GetExpansion() return 'vanilla' end
function ShaguTweaks:register(module) paletteModules[module.title]=module; return module end
QuestLogDetailScrollChildFrame={GetWidth=function() return 100 end,GetHeight=function() return 100 end}
local writes=0
local originalSetter=function() writes=writes+1 end
TrinketMenu_MainFrame={SetBackdropBorderColor=originalSetter}
function CreateFrame() error('Disabled palettes must not create a frame') end
function ShaguTweaks.HookAddonOrVariable() error('Disabled palettes must not install addon hooks') end
ShaguTweaks_config={['Golden UI']=0,['Darkened UI']=0}
dofile((arg[1] or '.')..'/mods/dark-ui-elements.lua')
assert(paletteModules['Golden UI'] and paletteModules['Darkened UI'])
assert(not ShaguTweaks.UIBorder and not ShaguTweaks.UITint)
assert(writes==0 and TrinketMenu_MainFrame.SetBackdropBorderColor==originalSetter)
print('Default UI: disabled palettes leave TrinketMenu border setters and colors untouched')
-- An enabled palette must also skip TrinketMenu, including anonymous children
-- reached by recursive scanning and generic minimap recoloring.
local start=assert(string.find(source,'local function IsExcludedFrame',1,true))
local finish=assert(string.find(source,'local function LockAddonFrames',start,true))
local prefix='local tint={r=1,g=.78,b=.4,a=1}; local edge={r=.8,g=.62,b=.32,a=1}; '
local helpers=assert(loadstring(prefix..string.sub(source,start,finish-1)..'return {DarkenFrame,LockTree,FindAddonFrames,TintMinimapButton}'))()
local probe={GetName=function() return 'TrinketMenu_MainFrame' end}
function probe:GetChildren() error('TrinketMenu descendants must not be scanned') end
function probe:GetRegions() error('TrinketMenu textures must not be scanned') end
function probe:SetBackdropBorderColor() error('TrinketMenu border must not be recolored') end
local parent={GetName=function() return 'UIParent' end,GetChildren=function() return probe end}
helpers[1](parent)
helpers[2](probe)
helpers[3](parent)
helpers[4](probe)
assert(not matches('TrinketMenu_MainFrame'))
print('Active palettes: TrinketMenu recursive, persistent-hook and minimap recoloring paths are excluded')

local function texture(path)
  return { GetTexture = function() return path end,
    SetVertexColor = function(self, r, g, b) self.color = {r, g, b} end }
end
for _, name in ipairs({"TrinketMenu_IconFrame", "OutfitterMinimapButton"}) do
  local normal, pressed = texture(), texture()
  helpers[4]({
    GetName = function() return name end,
    GetNormalTexture = function() return normal end,
    GetPushedTexture = function() return pressed end,
    GetRegions = function() error("Only the baked button artwork should be tinted") end,
  })
  assert(normal.color[2] == .78 and pressed.color[3] == .4)
end
local atlasIcon = texture("Interface\\WorldMap\\WorldMap-Icon")
local atlasRim = texture("Interface\\Minimap\\MiniMap-TrackingBorder")
helpers[4]({GetName = function() return "AtlasCFMMinimapButton" end,
  GetRegions = function() return atlasIcon, atlasRim end})
assert(not atlasIcon.color and atlasRim.color[2] == .78)
