"""Replay the shipped TOC under Lua 5.1 with a strict Vanilla widget API.
Requires: pip install lupa. This is not a substitute for testing the DLL/client.
"""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1] / 'DoesItDie'
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
now=100; frames={}; chat={}; units={player='P',target='A',nameplate1='A'}
health={A={25,200},B={100,200},P={100,100}}; logEvent={}
local methods={}
function frame(kind,parent,name)
 local f={kind=kind,parent=parent,name=name,shown=true,scripts={},children={},width=100,height=20}
 if parent then table.insert(parent.children,f) end
 table.insert(frames,f)
 if name then _G[name]=f end
 return setmetatable(f,{__index=function(_,k)
   if not methods[k] and k:match('^%u') then error('Unsupported Vanilla widget method: '..k) end
   return methods[k]
 end})
end
function methods.SetScript(s,k,v) s.scripts[k]=v end
function methods.RegisterEvent(s,k) s.events=s.events or {}; s.events[k]=true end
function methods.RegisterUnitEvent(s,k) methods.RegisterEvent(s,k) end
function methods.UnregisterEvent(s,k) s.events[k]=nil end
function methods.GetObjectType(s) return s.kind end
function methods.GetFrameLevel(s) return s.level or 1 end
function methods.SetFrameLevel(s,v) s.level=v end
function methods.GetWidth(s) return s.width end
function methods.GetHeight(s) return s.height end
function methods.SetParent(s,parent)
 if s.parent then
  for i,child in ipairs(s.parent.children) do if child==s then table.remove(s.parent.children,i); break end end
 end
 s.parent=parent; table.insert(parent.children,s)
end
function methods.SetWidth(s,v) s.width=v end
function methods.SetHeight(s,v) s.height=v end
function methods.SetAllPoints() end
function methods.SetPoint(s,...) s.point={...} end
function methods.ClearAllPoints() end
function methods.Show(s) s.shown=true end
function methods.Hide(s) s.shown=false end
function methods.IsShown(s) return s.shown end
function methods.IsVisible(s) return s.shown and (not s.parent or s.parent:IsVisible()) end
function methods.SetTexture(s,v) s.texture=v; return true end
function methods.SetTexCoord(s,...) s.coords={...} end
function methods.SetVertexColor(s,...) s.color={...} end
function methods.SetFont() end
function methods.SetText(s,v) s.text=v end
function methods.SetFrameStrata(s,v) s.strata=v end
function methods.SetBackdrop() end
function methods.EnableMouse() end
function methods.SetMovable() end
function methods.RegisterForDrag() end
function methods.StartMoving() end
function methods.StopMovingOrSizing() end
function methods.SetNormalTexture() end
function methods.SetPushedTexture() end
function methods.SetCheckedTexture() end
function methods.SetChecked(s,v) s.checked=v end
function methods.GetChecked(s) return s.checked end
function methods.CreateTexture(s) return frame('Texture',s) end
function methods.CreateFontString(s) return frame('FontString',s) end
function methods.GetChildren(s) return unpack(s.children) end
function CreateFrame(kind,name,parent) return frame(kind,parent,name) end
UIParent=frame('Frame'); TargetFrameHealthBar=frame('StatusBar',UIParent)
TargetFramePortrait=frame('Texture',UIParent); UISpecialFrames={}; SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function(_,s) table.insert(chat,s) end}
function GetTime() return now end
partyCount=0; raidCount=0
function GetNumPartyMembers() return partyCount end
function GetNumRaidMembers() return raidCount end
function UnitGUID(u) return units[u] or (health[u] and u) end
function UnitExists(u) return UnitGUID(u)~=nil end
function UnitName(u) return UnitGUID(u) end
function UnitIsDead(u) return false end
function UnitCanAttack(_,u) return u~='player' end
function UnitHealth() return 100 end
function UnitHealthMax() return 100 end
function GetUnitField(u,k)
 local data=health[UnitGUID(u)]
 return data and data[k=='health' and 1 or 2]
end
function GetComboPoints() return 0 end
function GetLocale() return 'enUS' end
function GetModernScriptArgs() return true end
function GetBuildInfo() return '1.12.1','5875','',11200 end
categories={}
function InterfaceOptions_AddCategory(panel) table.insert(categories,panel); panel:Hide() end
function InterfaceOptionsFrame_OpenToCategory(panel)
 activeCategory=panel; panel.refresh(); panel:Show()
end
function strtrim(s) return s:match('^%s*(.-)%s*$') end
strlower=string.lower
function table.wipe(t) for k in pairs(t) do t[k]=nil end end
CLASSIC_API_VERSION=11706
C_Spell={GetSpellName=function(id) if id==172 then return 'Corruption' end end,
 GetSpellDescription=function(id) if id==172 then return 'Corrupts the target, causing 40 Shadow damage over 12 sec.' end end}
plate=frame('Button',UIParent)
local scaled=frame('Frame',plate)
plate.healthbar=frame('StatusBar',scaled) -- ShaguTweaks reparented bar
C_NamePlate={GetNamePlates=function() return {plate} end,
 GetNamePlateGUIDs=function() return {'A'} end,
 GetNamePlateForGUID=function(g) if g=='A' then return plate end end,
 GetNamePlateForUnit=function(u) if UnitGUID(u)=='A' then return plate end end}
function CombatLogGetCurrentEventInfo() return unpack(logEvent,1,24) end
function fire(e,...)
 for _,f in ipairs(frames) do
  if rawget(f,'events') and f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f,e,...) end
 end
end
function cast()
 fire('UNIT_SPELLCAST_SENT','player','A','cast',172)
 fire('UNIT_SPELLCAST_SUCCEEDED','player','cast',172)
end
function combat(event,source,dest,amount,name)
 logEvent={[1]=now,[2]=event,[4]=source,[8]=dest,[12]=172,[13]=name or 'Corruption',[14]=32,[15]=amount}
 fire('COMBAT_LOG_EVENT_UNFILTERED')
end
function total() return DoesItDieVanilla.tracking.targetRemainingDamage() end
''')
for line in (ROOT / 'DoesItDie.toc').read_text().splitlines():
    if line.endswith('.lua'):
        lua.execute((ROOT / line).read_text(encoding='utf-8'))

lua.execute(r'''
fire('ADDON_LOADED','DoesItDie')
assert(DoesItDieVanilla.db)
cast(); assert(total()==40)
combat('SPELL_PERIODIC_DAMAGE','other','A',99); assert(total()==40)
combat('SPELL_DAMAGE','P','A',99); assert(total()==40)
now=103; combat('SPELL_PERIODIC_DAMAGE','P','A',10); assert(total()==30)
assert(DoesItDieVanilla.db.ticks[172]==10)
-- Find the target and plate overlays, using their actual parents.
local target, np
for _,f in ipairs(frames) do
 if f.parent==TargetFrameHealthBar then target=f end
 if f.parent==plate.healthbar then np=f end
end
assert(target and np and target:IsShown() and np:IsShown())
local skullFrame=DoesItDieVanillaSkull
local skull=skullFrame.children[1]
assert(skullFrame.parent==UIParent and skullFrame.strata=='HIGH' and skullFrame:IsShown())
assert(skull:IsShown()) -- 30 remaining against 25 HP
assert(skull.texture=='Interface\\AddOns\\DoesItDie\\Textures\\Skull.tga')
assert(skull.coords[1]==0 and skull.coords[3]==0)
assert(skullFrame.point[2]==TargetFramePortrait)
TargetPortrait=TargetFramePortrait; TargetFramePortrait=nil
DoesItDieVanilla.refresh(); assert(skullFrame.point[2]==TargetPortrait)
local segment=target.children[2]
assert(math.abs(segment.width-12.5)<.01) -- only the current 25 HP is shaded
local old=GetUnitField; GetUnitField=nil
DoesItDieVanilla.refresh()
assert(not skull:IsShown() and not skullFrame:IsShown() and not segment:IsShown()) -- no HP vs percentage comparison
assert(target.children[1].text:find('HP unknown',1,true))
GetUnitField=old
-- GUID tracking survives target changes; names are never used as plate identity.
units.target='B'; fire('PLAYER_TARGET_CHANGED'); assert(total()==0)
units.target='A'; fire('PLAYER_TARGET_CHANGED'); assert(total()==30)
now=106; combat('SPELL_PERIODIC_MISSED','P','A','ABSORB'); assert(total()==20)
assert(DoesItDieVanilla.db.ticks[172]==10)
combat('SPELL_AURA_REMOVED','other','A',0); assert(total()==20)
combat('SPELL_AURA_REMOVED','P','A',0); assert(total()==0)
now=110; cast(); assert(total()==40)
combat('UNIT_DIED',nil,'A'); assert(total()==0)
now=120; cast(); combat('SPELL_MISSED','P','A','RESIST'); assert(total()==0)
now=130; cast(); now=133; combat('SPELL_PERIODIC_DAMAGE','P','A',10)
now=133.1; fire('UNIT_SPELLCAST_SENT','player','A','recast',172)
fire('UNIT_SPELLCAST_SUCCEEDED','player','recast',172)
combat('SPELL_MISSED','P','A','RESIST'); assert(total()==30) -- failed refresh restores old dot
SlashCmdList.DOESITDIE('status')
SlashCmdList.DOESITDIE('wait always'); assert(DoesItDieVanilla.db.waitFirstTick=='always')
SlashCmdList.DOESITDIE(''); assert(activeCategory==categories[1] and activeCategory:IsShown())
SlashCmdList.DOESITDIE(''); assert(#categories==4)
combat('SPELL_PERIODIC_MISSED','P','A','IMMUNE'); assert(total()==0)
-- ClassicAPI 1.17.10+: damage immunity arrives as DAMAGE_SHIELD_MISSED / IMMUNE.
DoesItDieVanilla.db.waitFirstTick='off'
now=150; cast(); assert(total()==40)
combat('DAMAGE_SHIELD_MISSED','P','A','IMMUNE','Thorns'); assert(total()==40) -- not this DoT
combat('DAMAGE_SHIELD_MISSED','other','A','IMMUNE'); assert(total()==40)
combat('DAMAGE_SHIELD_MISSED','P','A','IMMUNE'); assert(total()==0) -- right after the cast
now=160; cast(); now=163; combat('SPELL_PERIODIC_DAMAGE','P','A',10); assert(total()==30)
now=166; combat('DAMAGE_SHIELD_MISSED','P','A','IMMUNE'); assert(total()==0) -- on a later tick
-- Consume a full ramping Agony via the new identified combat-log path.
local spellName, description=C_Spell.GetSpellName,C_Spell.GetSpellDescription
C_Spell.GetSpellName=function(id) if id==980 then return 'Curse of Agony' end return spellName(id) end
C_Spell.GetSpellDescription=function(id)
 if id==980 then return 'Afflicts the target with agony, causing 72 Shadow damage over 24 sec.' end
 return description(id)
end
now=200
DoesItDieVanilla.db.waitFirstTick='off'
fire('UNIT_SPELLCAST_SENT','player','A','agony',980)
fire('UNIT_SPELLCAST_SUCCEEDED','player','agony',980)
assert(total()==72)
for i=1,12 do
 now=200+i*2
 logEvent={[1]=now,[2]='SPELL_PERIODIC_DAMAGE',[4]='P',[8]='A',[12]=980,
  [13]='Curse of Agony',[14]=32,[15]=i<=4 and 3 or (i<=8 and 6 or 9)}
 fire('COMBAT_LOG_EVENT_UNFILTERED')
end
assert(total()==0 and DoesItDieVanilla.db.ticks[980]==6)
SlashCmdList.DOESITDIE('reset'); assert(next(DoesItDieVanilla.db.ticks)==nil)
for _, wording in ipairs({
 'Transfers 15 health from the target to the caster every 3 sec. Lasts 30 sec.',
 'Transfers 15 health from the target to the caster every 3 sec for 30 sec.'
}) do
 C_Spell.GetSpellName=function(id) if id==18265 then return 'Siphon Life' end return spellName(id) end
 C_Spell.GetSpellDescription=function(id) if id==18265 then return wording end return description(id) end
 now=300
 fire('UNIT_SPELLCAST_SENT','player','A','siphon',18265)
 fire('UNIT_SPELLCAST_SUCCEEDED','player','siphon',18265)
 assert(total()==150)
 now=303
 logEvent={[1]=now,[2]='SPELL_PERIODIC_DAMAGE',[4]='P',[8]='A',[12]=18265,
  [13]='Siphon Life',[14]=32,[15]=15}
 fire('COMBAT_LOG_EVENT_UNFILTERED')
 assert(total()==135 and DoesItDieVanilla.db.ticks[18265]==15)
 combat('UNIT_DIED',nil,'A')
end
SlashCmdList.DOESITDIE('siphon')
-- Exact OctoWoW tooltip supplied in the report: total transfer, decimal duration.
C_Spell.GetSpellDescription=function(id)
 if id==18265 then return 'Transfers 450 Health from the target to the caster over 24.60 sec.' end
 return description(id)
end
now=400
SlashCmdList.DOESITDIE('reset')
fire('UNIT_SPELLCAST_SENT','player','A','siphon-octo',18265)
fire('UNIT_SPELLCAST_SUCCEEDED','player','siphon-octo',18265)
local dots=DoesItDieVanilla.dotBreakdownForUnit('target')
assert(total()==450 and dots[1].school==32)
for i=1,10 do
 now=400+i*2.46
 logEvent={[1]=now,[2]='SPELL_PERIODIC_DAMAGE',[4]='P',[8]='A',[12]=18265,
  [13]='Siphon Life',[14]=32,[15]=45}
 fire('COMBAT_LOG_EVENT_UNFILTERED')
 assert(total()==450-i*45)
end
assert(DoesItDieVanilla.db.ticks[18265]==45)
SlashCmdList.DOESITDIE('skull'); assert(skullFrame.point[2]==TargetPortrait and skullFrame:IsShown())
-- Native options registration, independent display flags and host callbacks.
assert(categories[1].name=='DoesItDie' and categories[2].parent=='DoesItDie')
local root, platesPage, focusPage, tracking=unpack(categories)
local function click(panel,key,value)
 for _,control in ipairs(panel.controls) do
  if control.key==key then control:SetChecked(value); control.scripts.OnClick(control); return end
 end
 error('Missing option '..key)
end
now=500; cast(); assert(skullFrame:IsShown())
root.refresh()
click(root,'showSkull',false); assert(not skullFrame:IsShown() and np:IsShown())
assert(DoesItDieVanilla.db.plateShowSkull)
click(root,'showLabel',false); assert(not target.children[1]:IsShown())
click(root,'showMarkers',false); assert(not segment:IsShown())
click(root,'targetEnabled',false); assert(not target:IsShown() and np:IsShown())
root.cancel(); assert(target:IsShown() and skullFrame:IsShown())
assert(DoesItDieVanilla.db.showLabel and DoesItDieVanilla.db.showMarkers)
platesPage.refresh()
click(platesPage,'plateShowLabel',false); assert(not np.children[2]:IsShown())
click(platesPage,'plateShowSkull',false); assert(not np.children[1]:IsShown())
click(platesPage,'plateShowMarkers',false); assert(not np.children[3]:IsShown())
click(platesPage,'nameplateMode',false); assert(not np:IsShown() and target:IsShown())
platesPage.okay(); assert(DoesItDieVanillaDB.nameplateMode=='off')
platesPage.refresh(); platesPage.default(); assert(np:IsShown())
platesPage.cancel(); assert(not np:IsShown()) -- defaults can be cancelled
tracking.refresh(); click(tracking,'estimateDuringCast',false)
click(tracking,'debug',true)
local always=tracking.controls[5]
always.scripts.OnClick(always); assert(DoesItDieVanilla.db.waitFirstTick=='always')
tracking.cancel(); assert(DoesItDieVanilla.db.waitFirstTick=='off')
assert(DoesItDieVanilla.db.estimateDuringCast and not DoesItDieVanilla.db.debug)
-- Radio-like tick controls and Defaults preserve exactly one selected mode.
tracking.refresh(); always.scripts.OnClick(always); tracking.okay()
tracking.refresh(); tracking.default(); assert(DoesItDieVanilla.db.waitFirstTick=='off')
tracking.cancel(); assert(DoesItDieVanilla.db.waitFirstTick=='always')
-- pfUI loads late, replaces Blizzard frames and keeps disabled native plate bars.
now=600
DoesItDieVanilla.db.waitFirstTick='off'
DoesItDieVanilla.db.nameplateMode='markerIcon'
DoesItDieVanilla.db.plateShowLabel=true
DoesItDieVanilla.db.plateShowSkull=true
DoesItDieVanilla.db.plateShowMarkers=true
local pfTarget=frame('Frame',UIParent)
pfTarget.hp={bar=frame('StatusBar',pfTarget)}
pfTarget.portrait=frame('Frame',pfTarget)
pfTarget.config={invert_healthbar='0'}
local pfFocus=frame('Frame',UIParent)
pfFocus.hp={bar=frame('StatusBar',pfFocus)}
pfFocus.config={invert_healthbar='0'}
pfUI={uf={target=pfTarget,focus=pfFocus}}
units.focus='A'
TargetFrameHealthBar:Hide()
local replacement=frame('Frame',plate)
replacement.health=frame('StatusBar',replacement)
replacement.castbar=frame('StatusBar',replacement)
replacement.original={healthbar=plate.healthbar}
plate.nameplate=replacement
plate.healthbar:Hide()
cast()
assert(target.parent==pfTarget.hp.bar and target:IsVisible())
assert(skullFrame.point[2]==pfTarget.portrait and skullFrame:IsShown())
assert(target.children[1].point[2]==pfTarget.hp.bar)
assert(not np:IsVisible())
local pfOverlay=replacement.health.children[1]
assert(pfOverlay and pfOverlay:IsVisible())
assert(pfOverlay.children[2].point[2]==replacement.castbar)
replacement.castbar:Hide(); DoesItDieVanilla.refresh()
assert(pfOverlay.children[2].point[2]==replacement.health)
assert(pfFocus.hp.bar.children[1]:IsVisible())
pfTarget.portrait:Hide(); DoesItDieVanilla.refresh()
assert(skullFrame.point[1]=='RIGHT' and skullFrame.point[2]==pfTarget.hp.bar)
pfTarget.config.invert_healthbar='1'; DoesItDieVanilla.refresh()
assert(math.abs(segment.point[4]-87.5)<.01 and math.abs(segment.width-12.5)<.01)
pfTarget.config.invert_healthbar='0'; pfTarget.config.verticalbar='1'
DoesItDieVanilla.refresh()
assert(segment.point[1]=='BOTTOMLEFT' and math.abs(segment.height-2.5)<.01)
pfTarget:Hide(); DoesItDieVanilla.refresh(); assert(not skullFrame:IsShown())
pfTarget:Show()
local custom=CreateFrame('StatusBar','MyCustomTarget',UIParent)
DoesItDieVanilla.db.customHealthBar='MyCustomTarget'; DoesItDieVanilla.refresh()
assert(target.parent==custom)
DoesItDieVanilla.db.customHealthBar=''
pfUI=nil; TargetFrameHealthBar:Show(); DoesItDieVanilla.refresh()
assert(target.parent==TargetFrameHealthBar and skullFrame.point[2]==TargetPortrait)
-- Group suppression covers every overlay and updates without a reload.
root.refresh()
click(root,'disableInParty',true)
partyCount=1; DoesItDieVanilla.refresh()
assert(not target:IsShown() and not skullFrame:IsShown() and not pfOverlay:IsShown())
partyCount=0; DoesItDieVanilla.refresh(); assert(target:IsShown())
partyCount=4; raidCount=10; DoesItDieVanilla.refresh()
assert(target:IsShown()) -- party toggle must not suppress raids
click(root,'disableInRaid',true); assert(not target:IsShown())
SlashCmdList.DOESITDIE('skull'); assert(not skullFrame:IsShown())
root.cancel(); assert(target:IsShown())
root.refresh(); click(root,'disableInRaid',true); root.okay()
assert(DoesItDieVanillaDB.disableInRaid)
raidCount=0; partyCount=0; DoesItDieVanilla.refresh(); assert(target:IsShown())
''')
print('PASS: full TOC, native widgets, player-only periodic log, actual HP, unknown HP safety,')
print('      ShaguTweaks reparented plate, GUID target changes, absorbs, removals, death, misses, options')
print('      ClassicAPI categories, independent display toggles, Okay/Cancel/Defaults, tracking policies')
print('      pfUI late initialization, target/focus, replacement plates, portraits, vertical/inverted bars, custom overrides')
