assert(loadfile('gui/purchase_summary.lua'))
M={}
tinsert=table.insert
sort=table.sort
function module() end
local function region()
 local f={height=14,width=150}
 function f:SetWidth(v) self.width=v end
 function f:SetHeight(v) self.height=v end
 function f:GetHeight()
  if self.text then return math.max(1,math.ceil(string.len(self.text)*7/self.width))*14 end
  return self.height
 end
 function f:SetText(v) self.text=tostring(v) end
 function f:SetPoint(point) self.point=point end
 function f:ClearAllPoints() end
 function f:SetClampedToScreen() end
 function f:EnableMouseWheel() end
 function f:SetScrollChild() end
 function f:SetScript(k,v) self[k]=v end
 function f:SetVerticalScroll(v) self.scroll=v end
 function f:GetVerticalScroll() return self.scroll or 0 end
 function f:GetEffectiveScale() return 1 end
 function f:GetWidth() return self.width end
 function f:GetLeft() return 0 end
 function f:GetRight() return 800 end
 function f:GetTop() return 430 end
 function f:SetFrameLevel() end
 function f:GetFrameLevel() return 1 end
 function f:SetJustifyH() end
 function f:SetTextColor() end
 function f:Hide() end
 function f:Show() end
 function f:CreateFontString() return region() end
 return f
end
UIParent=region()
UIParent:SetWidth(1200)
UIParent:SetHeight(800)
function CreateFrame() local f=region(); if not panel then panel=f end; return f end
local color=function() return 1,1,1 end
aux={frame=region(),account_data={purchase_summary=true},handle={},color={label={enabled=color},text={enabled=color}},round=function(v) return math.floor(v+.5) end,size=function(t) local n=0; for k in t do n=n+1 end; return n end}
function require(name)
 if name=='aux' then return aux end
 if name=='aux.gui' then return {is_blizzard=function() return true end,set_panel_style=function() end} end
 if name=='aux.util.money' then return {to_string=function(v) return tostring(v) end} end
 return {wipe=function(t) for k in t do t[k]=nil end; table.setn(t, 0) end}
end
dofile('gui/purchase_summary.lua')
M.add_purchase("Dath'Zon 's Tel'Abim Medley",nil,3,50000)
M.add_purchase('Elixir of Fortitude',nil,3,10000)
M.update_display()
local total=50
local wrapped=false
for _,row in panel.rows do
 assert(row.height>=row.item_text:GetHeight()+2)
 total=total+row.height
 if row.item_text:GetHeight()>14 then wrapped=true end
end
assert(wrapped and panel.height==total)
M.update_display()
assert(table.getn(panel.rows)==2 and panel.height==total)
print('PASS Lua 5.0: wrapped names fit rows; panel fits content; rows reused')

aux.account_data.purchase_sidebar=true
for i=1,45 do M.add_purchase('Extra item '..i,nil,1,10) end
M.update_display()
assert(panel.point=='TOPLEFT' and panel.height<=420 and panel.scroll_limit>0)
this, arg1 = panel.viewport, -1
panel.viewport.OnMouseWheel()
assert(panel.viewport:GetVerticalScroll()>0)
UIParent:SetWidth(900)
M.update_display()
assert(panel.point=='BOTTOM')
print('PASS sidebar docks when there is room, scrolls, and falls back above Aux')
