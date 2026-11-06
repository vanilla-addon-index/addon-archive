
unpack = unpack or table.unpack
getglobal = function(n) return _G[n] end
now = 100
GetTime = function() return now end
SlashCmdList = {}
messages = {}
DEFAULT_CHAT_FRAME = {AddMessage=function(self,s) table.insert(messages,s) end}
DebuffTypeColor = {none={r=.8,g=0,b=0}, Magic={r=0,g=.5,b=1}, Poison={r=0,g=1,b=0}}
frames = {}
local M = {}
function M:GetName() return self.name end
function M:SetAllPoints(x) self.allPoints=x end
function M:GetFrameLevel() return self.level or 1 end
function M:SetFrameLevel(n) self.level=n end
function M:SetFont(path,size,flags) self.font=path; self.fontSize=size end
function M:SetPoint(...) self.point={...} end
function M:ClearAllPoints() self.point=nil end
function M:Show() self.shown=true end
function M:Hide() self.shown=false end
function M:IsShown() return self.shown end
function M:SetWidth(v) self.width=v end
function M:SetHeight(v) self.height=v end
function M:SetText(v) self.text=v end
function M:SetTextColor(...) self.color={...} end
function M:SetVertexColor(...) self.color={...} end
function M:SetTexture(v) self.texture=v end
function M:SetTexCoord(...) self.coords={...} end
function M:SetScript(k,v) self.scripts[k]=v end
function M:RegisterEvent(k) self.events[k]=true end
function M:UnregisterEvent(k) self.events[k]=nil end
function M:SetChecked(v) self.checked=v end
function M:GetChecked() return self.checked end
function M:SetMinMaxValues(a,b) self.min=a; self.max=b end
function M:SetValueStep(v) self.step=v end
function M:SetValue(v)
 self.value=v
 if self.scripts.OnValueChanged then local old=this; this=self; self.scripts.OnValueChanged(); this=old end
end
function M:GetValue() return self.value end
function M:SetCooldown(start,duration) self.start=start; self.duration=duration; self.calls=(self.calls or 0)+1; self:Show() end
function M:SetReverse(v) self.reverse=v end
function M:SetDrawEdge(v) self.edge=v end
function M:IsOwned(button) return self.owner==button end
function M:SetOwner(button) self.owner=button end
function M:SetUnitAura(unit,index,filter) self.tooltip={unit,index,filter} end
local function New(name)
 local f=setmetatable({name=name,shown=true,scripts={},events={}}, {__index=M})
 if name then _G[name]=f end
 return f
end
function M:CreateFontString(name) return New(name) end
function M:CreateTexture(name) return New(name) end
function CreateFrame(kind,name,parent,template)
 if kind=="Cooldown" and noCooldown then error("Unknown frame type") end
 local f=New(name); f.parent=parent; f.kind=kind
 table.insert(frames,f)
 if template=="UICheckButtonTemplate" then New(name.."Text") end
 if template=="OptionsSliderTemplate" then New(name.."Text"); New(name.."Low"); New(name.."High") end
 return f
end
UIParent=New("UIParent")
GameTooltip=New("GameTooltip")
TargetFrame=New("TargetFrame")
TargetFrameBuffFrame=New("TargetFrameBuffFrame")
for i=1,32 do New("TargetFrameBuff"..i); New("TargetFrameBuff"..i.."Icon") end
for i=1,16 do New("TargetFrameDebuff"..i); New("TargetFrameDebuff"..i.."Icon"); New("TargetFrameDebuff"..i.."Count"); New("TargetFrameDebuff"..i.."Border") end
TargetDebuffButton_Update=function() end
auras={HELPFUL={},HARMFUL={}}
nativeBuffs={}
nativeDebuffs={}
UnitBuff=function(u,i) return nativeBuffs[i] end
UnitDebuff=function(u,i) local a=nativeDebuffs[i]; if a then return unpack(a) end end
calls={index=0,slots=0,bySlot=0}
local epoch=0
local slotMap={}
function Aura(icon,count,duration,expiration,removable,dispel)
 return {icon,icon,count or 1,dispel or "Magic",duration or 30,expiration or 130,"player",removable or false}
end
function InstallAPI(batched)
 C_UnitAuras={}
 C_UnitAuras.UnitAura=function(u,i,filter)
  calls.index=calls.index+1
  local a=auras[filter][i]
  if a then return unpack(a,1,8) end
 end
 if batched then
  C_UnitAuras.GetAuraSlots=function(u,filter,max,token,buf)
   calls.slots=calls.slots+1; epoch=epoch+1; slotMap={}
   local n=table.getn(auras[filter])
   for i=1,n do buf[i]=epoch*1000+i; slotMap[buf[i]]=auras[filter][i] end
   for i=n+1,table.getn(buf) do buf[i]=nil end
   buf.n=n
   return nil,n
  end
  C_UnitAuras.UnitAuraBySlot=function(u,id)
   calls.bySlot=calls.bySlot+1
   assert(slotMap[id],"stale slot used")
   return unpack(slotMap[id],1,8)
  end
 end
end
function LoadSettings()
 for _,f in ipairs(frames) do
  if f.events.ADDON_LOADED then
   this=f; arg1="TargetFrameBuff"; f.scripts.OnEvent()
  end
 end
end
function Tick() TargetFrameBuff_Update(); TargetFrameBuff_OnUpdate(.2) end
