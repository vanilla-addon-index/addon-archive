-- Minimal stand-in for the WoW 1.12 API, enough to load Ashen Builds and drive its UI in tests.
-- Tests run on Lua 5.1 (lupa); the 5.0 names the addon uses are mapped onto it.
string.gfind=string.gmatch; math.mod=math.fmod
local Frame={}
local allFrames={}
local function New(kind,name,parent)
  local f=setmetatable({_kind=kind,_name=name,_parent=parent,_w=100,_h=20,_shown=true,_text="",_scripts={},_kids={},_level=(parent and parent._level or 0)+1},Frame)
  if parent and parent._kids then table.insert(parent._kids,f) end
  if name then _G[name]=f end
  table.insert(allFrames,f)
  return f
end
Frame.__index=function(t,k)
  local m=rawget(Frame,k); if m then return m end
  if string.find(k,'^%u') then return function() return nil end end
  return nil
end
function Frame:SetWidth(w) self._w=w end function Frame:GetWidth() return self._w end
function Frame:SetHeight(h) self._h=h end function Frame:GetHeight() return self._h end
function Frame:SetText(t) self._text=t==nil and "" or tostring(t); if self._scripts.OnTextChanged then local o=this; this=self; self._scripts.OnTextChanged(); this=o end end
function Frame:GetText() return self._text end
function Frame:Show() local was=self._shown; self._shown=true; if not was and self._scripts.OnShow then local o=this; this=self; self._scripts.OnShow(); this=o end end
function Frame:Hide() local was=self._shown; self._shown=false; if was and self._scripts.OnHide then local o=this; this=self; self._scripts.OnHide(); this=o end end
function Frame:IsShown() return self._shown end
function Frame:SetScript(k,f) self._scripts[k]=f end function Frame:GetScript(k) return self._scripts[k] end
function Frame:CreateFontString() return New("FontString",nil,self) end
function Frame:CreateTexture() return New("Texture",nil,self) end
function Frame:GetChildren() local out={} for _,k in ipairs(self._kids) do if k._kind~="FontString" and k._kind~="Texture" then table.insert(out,k) end end return unpack(out) end
function Frame:GetObjectType() return self._kind end
function Frame:GetEffectiveScale() return 1 end
function Frame:GetScale() return self._scale or 1 end function Frame:SetScale(v) self._scale=v end function Frame:SetParent(p) if self._parent and self._parent._kids then for i,k in ipairs(self._parent._kids) do if k==self then table.remove(self._parent._kids,i) break end end end self._parent=p; if p and p._kids then table.insert(p._kids,self) end end
function Frame:GetName() return self._name end
function Frame:GetParent() return self._parent end
function Frame:SetChecked(v) self._checked=v end function Frame:GetChecked() return self._checked end
function Frame:GetVerticalScroll() return 0 end function Frame:GetVerticalScrollRange() return 0 end
function Frame:GetNormalTexture() return New("Texture") end
function Frame:GetPushedTexture() return New("Texture") end
function Frame:GetHighlightTexture() return New("Texture") end
function Frame:GetDisabledTexture() return New("Texture") end
function Frame:Click(button) local o,oa=this,arg1; this=self; arg1=button or "LeftButton"; self._scripts.OnClick(); this=o; arg1=oa end
function CreateFrame(kind,name,parent,template)
  local f=New(kind,name,parent)
  if name then _G[name.."EditBox"]=New("EditBox") end
  return f
end
UIParent=New("Frame","UIParent"); UIParent._w=1600; UIParent._h=900
CHAT_LOG={}; DEFAULT_CHAT_FRAME={AddMessage=function(_,m) table.insert(CHAT_LOG,m) end}
GameTooltip=New("GameTooltip","GameTooltip")
function UnitClass() return "Warrior","WARRIOR" end; function UnitRace() return "Human","Human" end; function UnitLevel() return 60 end
function UnitName() return "Tester" end
function time() return os.time() end; UISpecialFrames={}; function tinsert(t,v) table.insert(t,v) end
function GetTime() return os.clock() end
function IsShiftKeyDown() return nil end function IsControlKeyDown() return nil end
function GetRealmName() return "Realm" end
SlashCmdList={}
function Fire(f,script,a1) local o,oa=this,arg1; this=f; arg1=a1; f._scripts[script](); this=o; arg1=oa end
STUB_FRAMES=allFrames
function Frame:SetPoint(...) self._points=self._points or {}; table.insert(self._points,{...}) end function Frame:ClearAllPoints() self._points={} end
function Frame:GetFrameLevel() return self._level or 1 end function Frame:SetFrameLevel(v) self._level=v end

Minimap=New("Frame","Minimap"); function Frame:GetCenter() return 800,450 end
function GetCursorPosition() return 900,450 end

-- Chat, channels and groups (nobody else online).
function GetChannelName() return 0 end
function JoinChannelByName() end
function LeaveChannelByName() end
function IsInGuild() return nil end
function GetNumRaidMembers() return 0 end
function GetNumPartyMembers() return 0 end
function SendAddonMessage() end
function SendChatMessage() end
function PlaySound() end
function GetItemInfo() return nil end
getglobal = function(n) return _G[n] end
date = os.date

-- Fires a game event at every frame that listens for events.
function FireEvent(name, a1, a2, a3, a4, a5, a6, a7, a8, a9)
  for _, f in ipairs(STUB_FRAMES) do
    if f._scripts.OnEvent then
      event = name; arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = a1, a2, a3, a4, a5, a6, a7, a8, a9
      this = f; f._scripts.OnEvent()
    end
  end
end

-- Runs every frame's OnUpdate once (one rendered frame).
function RunFrame(elapsed)
  for _, f in ipairs(STUB_FRAMES) do
    local s = f._scripts.OnUpdate
    if s then this = f; arg1 = elapsed or 0.016; s() end
  end
end

function Click(button, mouse)
  this = button; arg1 = mouse or "LeftButton"; button:GetScript("OnClick")()
end
