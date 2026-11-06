import sys
from pathlib import Path
import xml.etree.ElementTree as ET
from lupa.lua51 import LuaRuntime

addon = Path(__file__).resolve().parents[1]
mock = Path(__file__).with_name("mock_wow.lua").read_text(encoding="utf-8-sig")
passed = 0
def run(name, setup, body):
    global passed
    lua = LuaRuntime()
    lua.execute(mock)
    lua.execute(setup)
    lua.execute((addon/"Settings.lua").read_text(encoding="utf-8-sig"))
    lua.execute((addon/"TargetFrameBuff.lua").read_text(encoding="utf-8-sig"))
    lua.execute("TargetFrameBuff_OnLoad(); LoadSettings()")
    lua.execute(body)
    passed += 1
    print("PASS", name)

run("batched scans, reordered icons/timers and fresh tooltip indices",
    'InstallAPI(true); auras.HELPFUL={Aura("A",1,30,130),Aura("B",1,40,140)}',
    '''
Tick()
assert(calls.index==0)
assert(TargetFrameBuff1Icon.texture=="A" and TargetFrameBuff1.timer.text=="30")
auras.HELPFUL={Aura("B",1,40,150),Aura("A",1,30,125)}
Tick()
assert(TargetFrameBuff1Icon.texture=="B" and TargetFrameBuff1.timer.text=="50")
assert(TargetFrameBuff2Icon.texture=="A" and TargetFrameBuff2.timer.text=="25")
this=TargetFrameBuff2; this.scripts.OnEnter()
assert(GameTooltip.tooltip[2]==2 and GameTooltip.tooltip[3]=="HELPFUL")
auras.HELPFUL={Aura("C",1,50,160)}
Tick()
assert(TargetFrameBuff1Icon.texture=="C" and not TargetFrameBuff2:IsShown())
assert(not GameTooltip:IsShown())
''')
run("overflow debuff stacks, borders and cleanup on reuse", 'InstallAPI(true)', '''
auras.HELPFUL={Aura("Buff",3)}
for i=1,18 do auras.HARMFUL[i]=Aura("Debuff"..i,4,20,120,false,"Poison") end
Tick()
assert(TargetFrameBuff1.auraCount.text==3)
assert(TargetFrameBuff2Icon.texture=="Debuff17")
assert(TargetFrameBuff2.auraIndex==17 and TargetFrameBuff2.auraFilter=="HARMFUL")
assert(TargetFrameBuff2.auraCount.text==4 and TargetFrameBuff2.auraBorder.color[2]==1)
this=TargetFrameBuff2; this.scripts.OnEnter()
assert(GameTooltip.tooltip[2]==17 and GameTooltip.tooltip[3]=="HARMFUL")
auras.HARMFUL={}; auras.HELPFUL={Aura("Buff"),Aura("Plain")}
Tick()
assert(not TargetFrameBuff2.auraCount:IsShown() and not TargetFrameBuff2.auraBorder:IsShown())
assert(not TargetFrameDebuff1:IsShown())
''')
run("removable buff highlight toggle", 'InstallAPI(true); auras.HELPFUL={Aura("Purge",1,30,130,true)}', '''
Tick(); assert(TargetFrameBuff1.auraBorder:IsShown())
SlashCmdList.TARGETFRAMEBUFF("highlight off"); Tick()
assert(not TargetFrameBuff1.auraBorder:IsShown())
SlashCmdList.TARGETFRAMEBUFF("highlight on"); Tick()
assert(TargetFrameBuff1.auraBorder:IsShown())
''')
run("sweep start, refresh, unchanged timer, disable, expiration and missing duration",
    'InstallAPI(true); auras.HELPFUL={Aura("A",1,30,130)}', '''
assert(not TargetFrameBuff1.cooldown)
SlashCmdList.TARGETFRAMEBUFF("sweeps on"); Tick()
local cd=TargetFrameBuff1.cooldown
assert(cd.start==100 and cd.duration==30 and cd.reverse==true and cd.edge==true)
local n=cd.calls; Tick(); assert(cd.calls==n)
auras.HELPFUL[1][6]=140; Tick(); assert(cd.start==110 and cd.calls==n+1)
SlashCmdList.TARGETFRAMEBUFF("sweeps off"); Tick(); assert(not cd:IsShown())
SlashCmdList.TARGETFRAMEBUFF("sweeps on"); Tick(); assert(cd:IsShown())
now=141; Tick(); assert(not cd:IsShown() and not TargetFrameBuff1.timer:IsShown())
auras.HELPFUL[1][5]=0; auras.HELPFUL[1][6]=0; Tick(); assert(not cd:IsShown())
''')
run("unknown timers, font size and warning settings", 'InstallAPI(true)', '''
auras.HELPFUL={Aura("A",1,0,0)}; Tick(); assert(not TargetFrameBuff1.timer:IsShown())
auras.HELPFUL={Aura("A",1,10,106)}; Tick()
assert(TargetFrameBuff1.timer.color[2]==1)
SlashCmdList.TARGETFRAMEBUFF("warning 10"); Tick()
assert(TargetFrameBuff1.timer.color[2]==.1)
SlashCmdList.TARGETFRAMEBUFF("size 14"); Tick()
assert(TargetFrameBuff1.timer.fontSize==14)
assert(TargetFrameBuff1.timer.font=="Fonts\\\\FRIZQT__.TTF")
SlashCmdList.TARGETFRAMEBUFF("timers off"); Tick(); assert(not TargetFrameBuff1.timer:IsShown())
SlashCmdList.TARGETFRAMEBUFF("timers on"); Tick(); assert(TargetFrameBuff1.timer:IsShown())
SlashCmdList.TARGETFRAMEBUFF("size 999"); assert(TargetFrameBuffDB.timerSize==14)
''')
run("older ClassicAPI and unsupported Cooldown fallback", '''
InstallAPI(false); noCooldown=true; auras.HELPFUL={Aura("Old",2,20,120)}
''', '''
SlashCmdList.TARGETFRAMEBUFF("sweeps on"); Tick()
assert(TargetFrameBuff1.noCooldown and TargetFrameBuff1.timer.text=="20")
assert(calls.index>0 and calls.slots==0)
auras.HELPFUL={Aura("Refreshed",1,30,140)}; Tick()
assert(TargetFrameBuff1Icon.texture=="Refreshed")
''')
run("native client fallback and settings persistence", '''
nativeBuffs={"Native"}; nativeDebuffs={{"Poison",3,"Poison"}}
TargetFrameBuffDB={timers=false,highlight=false,sweeps=false,timerSize=12,warning=7}
''', '''
Tick()
assert(TargetFrameBuff1Icon.texture=="Native")
assert(TargetFrameDebuff1Count.text==3)
assert(not TargetFrameBuff1.timer)
assert(TargetFrameBuffDB.timers==false and TargetFrameBuffDB.timerSize==12)
SlashCmdList.TARGETFRAMEBUFF("sweeps on"); Tick()
assert(not TargetFrameBuff1.cooldown)
''')
run("full 48-icon scan call budget and target clear", 'InstallAPI(true)', '''
for i=1,32 do auras.HELPFUL[i]=Aura("B"..i) end
for i=1,16 do auras.HARMFUL[i]=Aura("D"..i) end
calls={index=0,slots=0,bySlot=0}; Tick()
assert(calls.index==0 and calls.slots==2 and calls.bySlot==48)
assert(TargetFrameBuff32:IsShown() and TargetFrameDebuff16:IsShown())
auras={HELPFUL={},HARMFUL={}}; Tick()
assert(not TargetFrameBuff1:IsShown() and not TargetFrameDebuff16:IsShown())
''')
run("options panel controls, cancel and defaults", '''
InstallAPI(true)
InterfaceOptions_AddCategory=function(p) registered=p end
InterfaceOptionsFrame_OpenToCategory=function(p) p.refresh() end
''', '''
assert(registered.name=="TargetFrameBuff")
SlashCmdList.TARGETFRAMEBUFF("")
this=TargetFrameBuffOption3; this:SetChecked(true); this.scripts.OnClick()
assert(TargetFrameBuffDB.sweeps==true)
TargetFrameBuffSlider1:SetValue(13); assert(TargetFrameBuffDB.timerSize==13)
registered.cancel()
assert(TargetFrameBuffDB.sweeps==false and TargetFrameBuffDB.timerSize==9)
TargetFrameBuffDB.timerSize=15; registered.default(); assert(TargetFrameBuffDB.timerSize==9)
''')
run("corrupt saved settings recover", 'TargetFrameBuffDB={timerSize=999,warning=-1,timers="bad"}', '''
assert(TargetFrameBuffDB.timerSize==9 and TargetFrameBuffDB.warning==5 and TargetFrameBuffDB.timers==true)
''')
run("aura disappears just before hover and lower count overlay", 'InstallAPI(true); auras.HELPFUL={Aura("A")}; auras.HARMFUL={Aura("D",4)}', '''
Tick()
assert(TargetFrameDebuff1.auraCount.text==4)
assert(not TargetFrameDebuff1Count:IsShown())
auras.HELPFUL={}
this=TargetFrameBuff1; this.scripts.OnEnter()
assert(not GameTooltip:IsShown() and not TargetFrameBuff1.auraIndex)
''')
run("cached countdown avoids aura reads; silent recast fallback", 'InstallAPI(true); auras.HELPFUL={Aura("A",1,30,130)}', '''
calls={index=0,slots=0,bySlot=0}
now=101; TargetFrameBuff_OnUpdate(.2)
assert(calls.slots==0 and TargetFrameBuff1.timer.text=="29")
auras.HELPFUL[1][6]=150
TargetFrameBuff_OnUpdate(.2); assert(calls.slots==0)
TargetFrameBuff_OnUpdate(.1)
assert(calls.slots==2 and TargetFrameBuff1.timer.text=="49")
''')
run("unit event filtering and target change refresh", 'InstallAPI(true); auras.HELPFUL={Aura("A")}', '''
calls={index=0,slots=0,bySlot=0}
event="UNIT_AURA"; arg1="party1"; TargetFrameBuffFrame.scripts.OnEvent()
assert(calls.slots==0)
auras.HELPFUL={Aura("B")}; arg1="target"; TargetFrameBuffFrame.scripts.OnEvent()
assert(calls.slots==2 and TargetFrameBuff1Icon.texture=="B")
auras.HELPFUL={}; event="PLAYER_TARGET_CHANGED"; TargetFrameBuffFrame.scripts.OnEvent()
assert(not TargetFrameBuff1:IsShown())
''')
run("idle countdown stops but fallback discovers new timing", 'InstallAPI(true); auras.HELPFUL={Aura("A",1,0,0)}', '''
local writes=0
TargetFrameBuff1.timer.SetText=function() writes=writes+1 end
calls={index=0,slots=0,bySlot=0}
TargetFrameBuff_OnUpdate(.2); TargetFrameBuff_OnUpdate(.2)
assert(writes==0 and calls.slots==0)
auras.HELPFUL[1][5]=30; auras.HELPFUL[1][6]=130
TargetFrameBuff_OnUpdate(.1)
assert(writes==1 and TargetFrameBuff1.timer:IsShown())
SlashCmdList.TARGETFRAMEBUFF("timers off")
writes=0; TargetFrameBuff_OnUpdate(.2)
assert(writes==0 and not TargetFrameBuff1.timer:IsShown())
''')
run("delta mode removes polling and refreshes timing/reordering", 'InstallAPI(true); C_UnitAuras.GetAuraDataByAuraInstanceID=function() end; auras.HELPFUL={Aura("A")}', '''
assert(TargetFrameBuffFrame.events.UNIT_AURA_DELTA)
calls={index=0,slots=0,bySlot=0}
for i=1,20 do TargetFrameBuff_OnUpdate(.2) end
assert(calls.slots==0)
auras.HELPFUL={Aura("B",3,60,160)}
event="UNIT_AURA_DELTA"; arg1="party1"; arg2={updatedAuraInstanceIDs={1}}
TargetFrameBuffFrame.scripts.OnEvent(); assert(calls.slots==0)
arg1="target"; TargetFrameBuffFrame.scripts.OnEvent()
assert(calls.slots==2 and TargetFrameBuff1Icon.texture=="B" and TargetFrameBuff1.timer.text=="1m")
arg2.updatedAuraInstanceIDs[1]=999
now=101; TargetFrameBuff_OnUpdate(.2)
assert(TargetFrameBuff1.timer.text=="59" and calls.slots==2)
auras.HELPFUL={}; arg2={isFullUpdate=true}; TargetFrameBuffFrame.scripts.OnEvent()
assert(not TargetFrameBuff1:IsShown())
''')
run("delta mode refreshes target switches and spell/pet capability changes", 'InstallAPI(true); C_UnitAuras.GetAuraDataByAuraInstanceID=function() end', '''
auras.HELPFUL={Aura("A")}; event="PLAYER_TARGET_CHANGED"; TargetFrameBuffFrame.scripts.OnEvent()
assert(TargetFrameBuff1Icon.texture=="A")
calls={index=0,slots=0,bySlot=0}; event="UNIT_AURA"; arg1="target"; TargetFrameBuffFrame.scripts.OnEvent()
assert(calls.slots==0)
event="SPELLS_CHANGED"; TargetFrameBuffFrame.scripts.OnEvent(); assert(calls.slots==2)
event="UNIT_PET"; arg1="player"; TargetFrameBuffFrame.scripts.OnEvent(); assert(calls.slots==4)
''')
run("modern sweeps suppress native numbers and bling, clear on removal", '''
InstallAPI(true); auras.HELPFUL={Aura("A")}
local baseCreate=CreateFrame
CreateFrame=function(kind,name,parent,template)
 local f=baseCreate(kind,name,parent,template)
 if kind=="Cooldown" then
  f.SetHideCountdownNumbers=function(self,v) self.hideNumbers=v end
  f.SetDrawBling=function(self,v) self.bling=v end
  f.Clear=function(self) self.cleared=true; self:Hide() end
 end
 return f
end
''', '''
SlashCmdList.TARGETFRAMEBUFF("sweeps on")
local cd=TargetFrameBuff1.cooldown
assert(cd.hideNumbers==true and cd.bling==false)
SlashCmdList.TARGETFRAMEBUFF("sweeps off"); assert(cd.cleared and not cd:IsShown())
SlashCmdList.TARGETFRAMEBUFF("sweeps on"); cd.cleared=false
auras.HELPFUL={}; Tick(); assert(cd.cleared and not cd:IsShown())
''')
run("ShaguTweaks Debuff Timer overlap warns once, only with ClassicAPI", 'InstallAPI(true); auras.HELPFUL={Aura("A")}', '''
Tick(); assert(#messages==0)
TargetFrameDebuff1.cd={readable={}}
Tick(); Tick()
local n=0
for _,m in ipairs(messages) do if string.find(m,"Debuff Timer",1,true) then n=n+1 end end
assert(n==1)
''')
run("no warning on the native path", 'nativeBuffs={"Native"}; nativeDebuffs={}', '''
TargetFrameDebuff1.cd={readable={}}
Tick(); Tick()
for _,m in ipairs(messages) do assert(not string.find(m,"Debuff Timer",1,true)) end
''')
run("test mode fills all 32 buffs and 16 debuffs, then restores real auras", 'InstallAPI(true); auras.HELPFUL={Aura("Real")}', '''
Tick(); assert(TargetFrameBuff1Icon.texture=="Real" and not TargetFrameBuff2:IsShown())
SlashCmdList.TARGETFRAMEBUFF("test")
assert(TargetFrameBuff_IsTest())
for i=1,32 do assert(_G["TargetFrameBuff"..i]:IsShown() and _G["TargetFrameBuff"..i].timer.text) end
for i=1,16 do assert(_G["TargetFrameDebuff"..i]:IsShown() and _G["TargetFrameDebuff"..i].timer.text) end
assert(TargetFrameBuff5.auraBorder:IsShown() and not TargetFrameBuff6.auraBorder:IsShown())
assert(TargetFrameBuff4.auraCount.text==6)
this=TargetFrameBuff3; this.scripts.OnEnter()
assert(GameTooltip.tooltip==nil)
now=now+500; Tick(); TargetFrameBuff_OnUpdate(1)
for i=1,32 do assert(_G["TargetFrameBuff"..i]:IsShown()) end
SlashCmdList.TARGETFRAMEBUFF("test")
assert(not TargetFrameBuff_IsTest())
assert(TargetFrameBuff1Icon.texture=="Real" and not TargetFrameBuff2:IsShown())
''')
run("test mode custom counts, clamping, native path and bad input", 'nativeBuffs={}; nativeDebuffs={}', '''
SlashCmdList.TARGETFRAMEBUFF("test 3 5")
assert(TargetFrameBuff3:IsShown() and not TargetFrameBuff4:IsShown())
assert(TargetFrameDebuff5:IsShown() and not TargetFrameDebuff6:IsShown())
SlashCmdList.TARGETFRAMEBUFF("test 40 99")
assert(TargetFrameBuff32:IsShown() and TargetFrameDebuff16:IsShown())
SlashCmdList.TARGETFRAMEBUFF("test banana")
assert(TargetFrameBuff_IsTest())
SlashCmdList.TARGETFRAMEBUFF("test off")
assert(not TargetFrameBuff_IsTest() and not TargetFrameBuff1:IsShown() and not TargetFrameDebuff1:IsShown())
''')
run("max buffs and debuffs limit display, no spill when lowered", 'InstallAPI(true)', '''
for i=1,20 do auras.HELPFUL[i]=Aura("Buff"..i) end
for i=1,18 do auras.HARMFUL[i]=Aura("Debuff"..i) end
Tick()
assert(TargetFrameBuff20:IsShown() and TargetFrameDebuff16:IsShown())
assert(TargetFrameBuff21Icon.texture=="Debuff17")
SlashCmdList.TARGETFRAMEBUFF("buffs 5"); SlashCmdList.TARGETFRAMEBUFF("debuffs 3")
assert(TargetFrameBuffDB.maxBuffs==5 and TargetFrameBuffDB.maxDebuffs==3)
assert(TargetFrameBuff5:IsShown() and not TargetFrameBuff6:IsShown())
assert(TargetFrameBuff5Icon.texture=="Buff5")
assert(TargetFrameDebuff3:IsShown() and not TargetFrameDebuff4:IsShown())
SlashCmdList.TARGETFRAMEBUFF("debuffs 0"); assert(not TargetFrameDebuff1:IsShown())
SlashCmdList.TARGETFRAMEBUFF("buffs 0"); assert(not TargetFrameBuff1:IsShown())
SlashCmdList.TARGETFRAMEBUFF("buffs 40"); assert(TargetFrameBuffDB.maxBuffs==0)
SlashCmdList.TARGETFRAMEBUFF("debuffs x"); assert(TargetFrameBuffDB.maxDebuffs==0)
SlashCmdList.TARGETFRAMEBUFF("reset")
assert(TargetFrameBuffDB.maxBuffs==32 and TargetFrameBuffDB.maxDebuffs==16)
assert(TargetFrameBuff21:IsShown() and TargetFrameBuff21Icon.texture=="Debuff17")
''')
run("limits on the native path, corrupt values and options sliders", '''
nativeBuffs={"A","B","C","D"}; nativeDebuffs={{"X",1,"Magic"},{"Y",1,"Magic"},{"Z",1,"Magic"}}
TargetFrameBuffDB={maxBuffs=-5,maxDebuffs=99}
InterfaceOptions_AddCategory=function(p) registered=p end
InterfaceOptionsFrame_OpenToCategory=function(p) p.refresh() end
''', '''
Tick()
assert(TargetFrameBuffDB.maxBuffs==32 and TargetFrameBuffDB.maxDebuffs==16)
assert(TargetFrameBuff4:IsShown() and TargetFrameDebuff3:IsShown())
TargetFrameBuffSlider3:SetValue(2); TargetFrameBuffSlider4:SetValue(1)
assert(TargetFrameBuffDB.maxBuffs==2 and TargetFrameBuffDB.maxDebuffs==1)
assert(TargetFrameBuff2:IsShown() and not TargetFrameBuff3:IsShown())
assert(TargetFrameDebuff1:IsShown() and not TargetFrameDebuff2:IsShown())
''')
ET.parse(addon/"TargetFrameBuff.xml")
print("PASS XML parsing")
print(f"{passed} Lua regression scenarios passed; XML parsed.")
