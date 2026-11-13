local root=(arg[1] or '.')..'/'
local function Check(supported,animated)
 local module,frames,updates=nil,{},0
 local methods={}
 local function noop() end
 local function new()
  return setmetatable({shown=true,scripts={},events={}},{__index=function(t,k)
   if k=='CreateAnimationGroup' and not animated then return nil end
   return methods[k] or (string.find(k,'^[A-Z]') and noop)
  end})
 end
 function methods:Show() self.shown=true end
 function methods:Hide() self.shown=false end
 function methods:IsShown() return self.shown end
 function methods:IsVisible() return self.shown end
 function methods:GetFrameLevel() return 1 end
 function methods:SetScript(k,v) self.scripts[k]=v end
 function methods:RegisterEvent(k) self.events[k]=true end
 function methods:CreateAnimationGroup() return new() end
 function methods:CreateAnimation() return new() end
 function methods:CreateTexture() return new() end
 function methods:SetTexture(path) self.path=path end
 function methods:SetBlendMode(mode) self.blend=mode end
 function methods:SetToAlpha(value) self.minimum=value end
 function methods:Play() self.playing=true end
 function methods:Stop() self.playing=false end
 CreateFrame=function() local f=new();table.insert(frames,f);return f end
 ActionButton1=new();BonusActionButton1=new();MultiBarBottomLeftButton1=new()
 local slots={[ActionButton1]=1,[BonusActionButton1]=73,[MultiBarBottomLeftButton1]=61}
 local actions={[1]={'spell',10},[73]={'macro',2},[61]={'item',30}}
 local active={[10]=true,[20]=true}
 ActionButton_GetPagedID=function(b) return slots[b] end
 GetMacroSpell=function(id) return 'Spell','Rank',20 end
 C_SpellActivationOverlay={IsSpellOverlayed=function(id) return active[id] end}
 C_EventUtils={IsEventValid=function() return supported end}
 ShaguTweaks={T=setmetatable({},{__index=function(t,k) return k end}),
  GetGlobalEnv=function() return _G end,API={GetActionInfo=function(slot)
   updates=updates+1;local a=actions[slot];if a then return unpack(a) end
  end}}
 function ShaguTweaks:register(m) module=m;return m end
 function ShaguTweaks.HookScript(f,k,fn) f.scripts[k]=fn end
 local refresh
 function ShaguTweaks.hooksecurefunc(name,fn) assert(name=='ActionButton_Update');refresh=fn end
 dofile(root..'mods/actionbar-proc-highlights.lua');module:enable()
 if not supported then assert(not module.states and table.getn(frames)==0);return end
 assert(table.getn(module.states)==3)
 local a,b,c=module.states[1],module.states[2],module.states[3]
 assert(a.glow.shown and b.glow.shown and not c.glow.shown)
 assert(a.halo.path=='Interface\\Buttons\\UI-ActionButton-Border' and a.halo.blend=='ADD')
 assert(not module.events.scripts.OnUpdate and not a.glow.scripts.OnUpdate)
 if animated then assert(a.pulse.playing) else assert(not a.pulse) end
 local count=table.getn(frames);module:enable();assert(table.getn(frames)==count)
 local function emit(e,id) event,arg1=e,id;module.events.scripts.OnEvent() end
 local before=updates;active[20]=false;emit('SPELL_ACTIVATION_OVERLAY_GLOW_HIDE',20)
 assert(not b.glow.shown and a.glow.shown and updates==before)
 actions[13]={'spell',20};slots[ActionButton1]=13;emit('ACTIONBAR_PAGE_CHANGED')
 assert(not a.glow.shown and a.spell==20)
 active[20]=true;emit('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW',20);assert(a.glow.shown and b.glow.shown)
 ActionButton1:Hide();a.button.scripts.OnHide();assert(not a.glow.shown and not a.spell)
 ActionButton1:Show();a.button.scripts.OnShow();assert(a.glow.shown)
 actions[13]={'item',1};this=ActionButton1;refresh();this=nil;assert(not a.glow.shown)
 GetMacroSpell=function() return nil end;emit('UPDATE_MACROS');assert(not b.glow.shown)
end
Check(false,true);Check(true,true);Check(true,false)
print('Proc highlights: capability guard, existing procs, ranks/macros, event-only changes, paging, visibility, native animation/static fallback and idempotence passed')
