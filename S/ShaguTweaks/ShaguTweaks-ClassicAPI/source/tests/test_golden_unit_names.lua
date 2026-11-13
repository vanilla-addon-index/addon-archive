local root=(arg[1] or '.') .. '/'
local f=assert(io.open(root..'mods/dark-ui-elements.lua','r'));local source=f:read('*a');f:close();assert(loadstring(source))
local made=0
local methods={}
local function object()
 return setmetatable({level=7},{__index=methods})
end
function methods:SetWidth(v) self.width=v end
function methods:SetHeight(v) self.height=v end
function methods:SetFrameLevel(v) self.level=v end
function methods:GetFrameLevel() return self.level end
function methods:SetPoint(...) self.point=arg end
function methods:SetTexture(v) self.path=v end
function methods:SetTexCoord(...) self.coords=arg end
function methods:SetAllPoints(v) self.allPoints=v end
function methods:SetVertexColor(...) self.color=arg end
function methods:SetAlpha(v) self.alpha=v end
function methods:GetAlpha() return self.alpha or 1 end
function methods:Show() self.visible=true end
function methods:Hide() self.visible=false end
function methods:RegisterEvent() end
function methods:SetScript(event,fn) self[event]=fn end
function methods:SetFontObject(v) self.font=v end
function methods:GetFontObject() return 'DefaultGoldFont' end
function methods:GetJustifyH() return 'CENTER' end
function methods:SetJustifyH(v) self.justify=v end
function methods:SetText(v) self.text=v end
function methods:SetFormattedText(format,...) self.text=string.format(format,unpack(arg)) end
function methods:GetText() return self.text end
function methods:CreateTexture() return object() end
function methods:CreateFontString() return object() end
function CreateFrame() made=made+1;return object() end
local a=assert(string.find(source,'local function RedrawTitle',1,true))
local b=assert(string.find(source,'local function ShadeTitleBar',a,true))
local c=assert(string.find(source,'local function GoldenUnitNameBar',b,true))
local d=assert(string.find(source,'golden.enable =',c,true))
local prefix='local tint={r=1,g=.78,b=.4}; local golden={config={["goldmode.bar"]={r=.8,g=.63,b=.62}}}; '
local apply=assert(loadstring(prefix..string.sub(source,a,b-1)..string.sub(source,c,d-1)..'return GoldenUnitNameBar'))()
local parent=object();local title=object();title.text='First target'
function title:GetParent() return parent end
function title:GetPoint() return 'CENTER',parent,'CENTER',0,10 end
local target={name=title}
local isPlayer,exists=false,true
function UnitExists() return exists end
function UnitIsPlayer() return isPlayer end
ShaguTweaks={HookScript=function(frame,event,fn) frame[event]=fn end}
apply(target)
local bar=target.stGoldenNameBar
assert(bar and bar.width==119 and bar.height==14 and bar.level>parent.level)
assert(bar.texture.path=='Interface\\PaperDollInfoFrame\\UI-Character-General-TopLeft')
assert(bar.texture.color[4]==1 and math.abs(bar.texture.color[2]-.78*.63)<.00001)
assert(bar.title.font=='DefaultGoldFont' and title.alpha==0 and bar.title.text=='First target')
title:SetText('Next target');assert(bar.title.text=='Next target')
title:SetFormattedText('%s %d','Formatted target',2);assert(bar.title.text=='Formatted target 2')
local count=made;apply(target);assert(made==count)
assert(bar.visible)
isPlayer=true;bar.OnEvent();assert(not bar.visible and title.alpha==1)
title:SetText('Player target');assert(title:GetText()=='Player target')
isPlayer=false;bar.OnEvent();assert(bar.visible and title.alpha==0)
exists=false;bar.OnEvent();assert(not bar.visible and title.alpha==1)
exists=true;target.OnShow();assert(bar.visible and title.alpha==0)
-- Exercise actual enable gating while stubbing only unrelated window work.
T=setmetatable({},{__index=function(t,k) return k end})
golden={config={['goldmode.color']={},['goldmode.border']={},['goldmode.bar']={}}}
ShaguTweaks={};PlayerFrame={};TargetFrame={}
local seen,applied={},0
function Apply() applied=applied+1 end
function ShadeTitleBars() end
function RestoreMailParchment() end
function GoldenUnitNameBar(frame) seen[frame]=true end
assert(loadstring(string.sub(source,d)))()
ShaguTweaks_config={['Personal Resource Display']=1}
golden:enable();assert(seen[TargetFrame] and not seen[PlayerFrame])
ShaguTweaks_config={};seen={}
golden:enable();assert(seen[TargetFrame] and not seen[PlayerFrame])
ShaguTweaks_config={['Unit Frame Big Health for Player']=1};seen={}
golden:enable();assert(seen[TargetFrame] and not seen[PlayerFrame])
ShaguTweaks_config={['Unit Frame Big Health for Target']=1};seen={}
golden:enable();assert(not next(seen))
ShaguTweaks_config={['Unit Frame Big Health for Player']=1,['Unit Frame Big Health for Target']=1};seen={}
golden:enable();assert(not next(seen))
ShaguTweaks_config={['Darkened UI']=1};seen={}
golden:enable();assert(not next(seen) and applied==5)
print('Golden name headers: opaque native title texture, palette match, live text, font retention, idempotence, player exemption and Darkened UI precedence passed')
