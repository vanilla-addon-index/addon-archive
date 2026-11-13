-- Minimal vanilla frame environment for module lifecycle regression tests.
return function()
  local env=setmetatable({},{__index=getfenv(0)});env._G=env
  env.ShaguTweaks={T=setmetatable({},{__index=function(_,key)return key end}),API={}}
  env.ShaguTweaks.GetGlobalEnv=function()return env end
  env.ShaguTweaks.register=function(_,module)env.module=module;return module end
  env.frames,env.hooks={},{}
  local methods={}
  function methods:SetScript(key,value)self.scripts[key]=value end
  function methods:GetScript(key)return self.scripts[key] end
  function methods:RegisterEvent(key)self.events[key]=true end
  function methods:UnregisterEvent(key)self.events[key]=nil end
  function methods:UnregisterAllEvents()self.events={}end
  function methods:Hide()self.visible=false end
  function methods:Show()
    local was=self.visible;self.visible=true
    if not was and self.scripts.OnShow then
      local before=env.this;env.this=self;self.scripts.OnShow();env.this=before
    end
  end
  function methods:IsVisible()return self.visible end
  function methods:GetNormalTexture()return self end
  function methods:SetText(value)self.text=value end
  function methods:GetText()return self.text end
  function methods:SetAlpha(value)self.alpha=value end
  function methods:GetName()return self.name end
  function methods:GetID()return self.id end
  env.CreateFrame=function(_,name,parent)
    local frame=setmetatable({scripts={},events={},visible=true,alpha=1,name=name,parent=parent},
      {__index=function(_,key)
        if methods[key] then return methods[key] end
        if string.find(key,'^[A-Z]') then return function()end end
      end})
    table.insert(env.frames,frame);if name then env[name]=frame end;return frame
  end
  env.ShaguTweaks.hooksecurefunc=function(name,callback)env.hooks[name]=callback end
  env.ShaguTweaks.HookScript=function(frame,script,callback)frame:SetScript(script,callback)end
  env.DEFAULT_CHAT_FRAME={AddMessage=function()end}
  env.Invoke=function(frame,script,event,payload)
    local oldThis,oldEvent,oldArg=env.this,env.event,env.arg1
    env.this,env.event,env.arg1=frame,event,payload
    frame.scripts[script]()
    env.this,env.event,env.arg1=oldThis,oldEvent,oldArg
  end
  env.Load=function(path)
    local f=assert(io.open(path));local source=f:read('*a');f:close()
    local chunk=assert(loadstring(source,'@'..path));setfenv(chunk,env);chunk()
  end
  return env
end
