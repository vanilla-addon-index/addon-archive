local f=assert(io.open((arg[1] or '.') .. '/mods/dark-ui-elements.lua','r'))
local source=f:read('*a'); f:close(); assert(loadstring(source))
local first=assert(string.find(source,'local function IsSlotArtwork',1,true))
local last=assert(string.find(source,'local function DarkenFrame',first,true))
local apply=assert(loadstring(string.sub(source,first,last-1)..'return TintSlotBorder'))()
edge={r=.8,g=.62,b=.32}
local made=0
local button={}
function button:GetWidth() return 37 end
function button:GetHeight() return 37 end
function button:CreateTexture()
 made=made+1
 local c={}
 function c:SetTexture(p) self.path=p end
 function c:SetTexCoord(l,r,t,b) self.l,self.r,self.t,self.b=l,r,t,b end
 function c:SetWidth(w) self.w=w end
 function c:SetHeight(h) self.h=h end
 function c:SetPoint(point,parent) assert(parent==button) end
 function c:SetVertexColor(r,g,b,a) assert(r==edge.r and g==edge.g and b==edge.b and a==1) end
 function c:SetAlpha(a) assert(a==.7) end
 function c:Show() self.visible=true end
 function c:Hide() self.visible=false end
 return c
end
local tex={path='Interface\\Buttons\\UI-Slot-Background'}
function tex:GetTexture() return self.path end
function tex:GetTexCoord() return 0,0,0,.640625,.640625,0,.640625,.640625 end
function tex:SetVertexColor(r,g,b,a) assert(r==1 and g==1 and b==1 and a==1) end
function tex:GetAlpha() return .7 end
apply(tex,button)
assert(made==4)
local s=tex.stSlotEdges
assert(s[1].h==3 and s[2].h==3 and s[3].w==3 and s[4].w==3)
assert(math.abs(s[1].b-.640625*3/39)<.000001)
tex.path='Interface\\AddOns\\Bagshui\\Images\\ItemSlot\\EmptySlot-SoulBag'
apply(tex,button); assert(made==4)
tex.path=''; apply(tex,button)
for i=1,4 do assert(not s[i].visible) end
tex.path='Interface\\BUTTONS\\WHITE8X8'; apply(tex,button)
for i=1,4 do assert(not s[i].visible) end
print('Lua 5.0: syntax, unchanged background, button anchors, rim-only crops, reuse and cleanup passed')
