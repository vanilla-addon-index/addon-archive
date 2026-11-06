QuestieOcto.Visuals = QuestieOcto.Visuals or {}
local V = QuestieOcto.Visuals

local ICON_ROOT="Interface\\AddOns\\Questie-Octo\\UI\\Icons\\"
local TEX_GLOW=ICON_ROOT.."glow"

local function Settings()
  return QuestieOcto.MinimapSettings
end

local function NextRandom(seed)
  seed=math.mod(seed*214013+2531011,4294967296)
  local value=math.mod(math.floor(seed/65536),32768)/32767
  return seed,value
end

-- HSV->RGB (h in [0,360), s/v in [0,1]). Lua 5.0: math.mod is fmod and works on
-- floats, math.abs/math.floor are available.
local function HSVToRGB(h,s,v)
  local c=v*s
  local hp=h/60
  local x=c*(1-math.abs(math.mod(hp,2)-1))
  local r,g,b=0,0,0
  if hp<1 then r,g,b=c,x,0
  elseif hp<2 then r,g,b=x,c,0
  elseif hp<3 then r,g,b=0,c,x
  elseif hp<4 then r,g,b=0,x,c
  elseif hp<5 then r,g,b=x,0,c
  else r,g,b=c,0,x end
  local m=v-c
  return r+m,g+m,b+m
end

-- Full-wheel vivid colors. The previous scheme mapped each RGB channel into
-- [0.45,0.95], which clustered every roll near a light desaturated gray: little
-- variety and near-identical neighbours. Drawing a hue across the entire color
-- wheel with high saturation and brightness gives a far larger, more separable
-- gamut so overlapping quests/objectives are easy to tell apart, and re-rolling
-- (Full Node click) jumps to a clearly different color.
local function SeedColor(seed)
  seed=tonumber(seed) or 0
  local h,s,v
  seed,h=NextRandom(seed)
  seed,s=NextRandom(seed)
  seed,v=NextRandom(seed)
  local hue=h*360
  local sat=0.82+s*0.18   -- 0.82 .. 1.00: strongly saturated
  local val=0.85+v*0.15   -- 0.85 .. 1.00: bright/readable
  return HSVToRGB(hue,sat,val)
end

V.colorRolls=V.colorRolls or {}

function V:GetQuestColor(questID)
  questID=tonumber(questID) or 0
  -- Each Full Node click re-rolls the quest's color (see CycleQuestColor).
  local roll=self.colorRolls[questID] or 0
  return SeedColor(questID+roll*1000003)
end

-- Full Nodes: clicking a spawn dot re-rolls its quest's color so overlapping
-- quests can be told apart, mirroring pfQuest's node click behavior.
function V:CycleQuestColor(questID)
  questID=tonumber(questID)
  if not questID then return end
  self.colorRolls[questID]=(self.colorRolls[questID] or 0)+1
  if QuestieOcto.Map and QuestieOcto.Map.RefreshVisualSettings then
    QuestieOcto.Map:RefreshVisualSettings()
  elseif QuestieOcto.Minimap and QuestieOcto.Minimap.RefreshVisualSettings then
    QuestieOcto.Minimap:RefreshVisualSettings()
  end
end

function V:GetObjectiveColor(questID,objectiveIndex)
  return SeedColor((tonumber(questID) or 0)+32768*(tonumber(objectiveIndex) or 0))
end

function V:IsObjectiveRole(role)
  return role=="objectiveCreature" or role=="objectiveObject" or role=="objectiveItemSource"
end

function V:EnsureGlow(pin)
  if not pin or pin.glowTexture then return end

  -- Questie 3.3.5 compatibility bridge:
  -- glow = same icon frame, ARTWORK sublevel -1
  -- icon = same icon frame, OVERLAY
  local tex=pin:CreateTexture(nil,"ARTWORK")
  if tex.SetDrawLayer then tex:SetDrawLayer("ARTWORK",-1) end
  tex:SetTexture(TEX_GLOW)
  tex:SetWidth(18)
  tex:SetHeight(18)
  tex:SetPoint("CENTER",pin,"CENTER",0,0)
  tex:Hide()
  pin.glowTexture=tex
end

function V:ResizeGlow(pin)
  if not pin or not pin.glowTexture then return end
  local width=pin:GetWidth() or 16
  local height=pin:GetHeight() or 16
  pin.glowTexture:SetWidth(width*1.13)
  pin.glowTexture:SetHeight(height*1.13)
  pin.glowTexture:ClearAllPoints()
  pin.glowTexture:SetPoint("CENTER",pin,"CENTER",0,0)
end

function V:ClearPin(pin,alpha)
  if not pin then return end
  alpha=tonumber(alpha) or 1
  pin.iconR,pin.iconG,pin.iconB=1,1,1
  pin.glowR,pin.glowG,pin.glowB=1,1,1
  pin.glowShown=false
  pin.glowForced=nil
  if pin.texture then pin.texture:SetVertexColor(1,1,1,alpha) end
  if pin.glowTexture then pin.glowTexture:Hide() end
end

function V:ApplyPin(pin,node,isMinimap,alpha)
  if not pin or not node then return end
  alpha=tonumber(alpha) or 1

  self:EnsureGlow(pin)

  local objective=self:IsObjectiveRole(node.role)
  local colorEnabled
  local glowEnabled

  if isMinimap then
    colorEnabled=Settings():Get("questMinimapObjectiveColors") and true or false
    glowEnabled=Settings():Get("alwaysGlowMinimap") and true or false
  else
    colorEnabled=Settings():Get("questObjectiveColors") and true or false
    glowEnabled=Settings():Get("alwaysGlowMap") and true or false
  end

  local r,g,b=1,1,1
  -- Quest pickup/turn-in presentation priority is PvP > Repeatable > Event >
  -- Turtle low-level gray > Normal. Gray uses dedicated artwork like the other
  -- quest-start variants; objective tinting never recolors pickup/turn-in icons.
  if (node.pvp or node.repeatable) and (node.role=="available" or node.role=="itemStart" or node.role=="turnin") then
    r,g,b=1,1,1
  elseif objective and colorEnabled then
    r,g,b=self:GetQuestColor(node.questID)
  end
  pin.iconR,pin.iconG,pin.iconB=r,g,b
  if pin.texture then pin.texture:SetVertexColor(r,g,b,alpha) end

  if objective and glowEnabled and pin.glowTexture then
    local gr,gg,gb=self:GetObjectiveColor(node.questID,node.objectiveIndex)
    pin.glowR,pin.glowG,pin.glowB=gr,gg,gb
    pin.glowTexture:SetVertexColor(gr,gg,gb,alpha)
    self:ResizeGlow(pin)
    pin.glowTexture:Show()
    pin.glowShown=true
  elseif pin.glowTexture then
    pin.glowTexture:Hide()
    pin.glowShown=false
  end
end

-- Fixed light blue-white used for the hover-highlight glow. The highlight only
-- appears while every other objective is faded, so it never needs to be color
-- coded per quest; a neutral tint reads clearly against the vivid node colors
-- rather than blending into them.
local HIGHLIGHT_GLOW_R,HIGHLIGHT_GLOW_G,HIGHLIGHT_GLOW_B=0.50,0.70,1.0

-- Tracker-hover highlight: brighten a pin and force its glow on so the hovered
-- quest's objectives stand out, then restore the normal glow state on release.
function V:SetHighlight(pin,on)
  if not pin or not pin.texture then return end
  if on then
    pin.texture:SetVertexColor(pin.iconR or 1,pin.iconG or 1,pin.iconB or 1,1)
    if pin.glowTexture then
      pin.glowTexture:SetVertexColor(HIGHLIGHT_GLOW_R,HIGHLIGHT_GLOW_G,HIGHLIGHT_GLOW_B,1)
      self:ResizeGlow(pin)
      pin.glowTexture:Show()
      pin.glowForced=true
    end
  else
    pin.texture:SetVertexColor(pin.iconR or 1,pin.iconG or 1,pin.iconB or 1,1)
    if pin.glowForced and pin.glowTexture then
      pin.glowForced=nil
      if pin.glowShown then
        pin.glowTexture:SetVertexColor(pin.glowR or 1,pin.glowG or 1,pin.glowB or 1,1)
        pin.glowTexture:Show()
      else
        pin.glowTexture:Hide()
      end
    end
  end
end


function V:ApplyFullNode(pin,node,isMinimap,alpha)
  if not pin or not node or not pin.texture then return end
  -- pfQuest's ordinary spawn nodes are deliberately compact and subdued.
  -- Full Nodes use pfQuest's native 14px baseline and 15% transparency;
  -- the user's only size control is the global map/minimap scale.
  alpha=(tonumber(alpha) or 1)*0.85
  local r,g,b=self:GetQuestColor(node.questID)
  r,g,b=r*0.72,g*0.72,b*0.72
  pin.iconR,pin.iconG,pin.iconB=r,g,b
  pin.texture:SetTexture("Interface\\AddOns\\Questie-Octo\\UI\\Icons\\pfquest_node")
  pin.texture:SetVertexColor(r,g,b,alpha)
  if pin.glowTexture then pin.glowTexture:Hide() end
  pin.glowShown=false
  pin.fullNode=true
  pin.fullNodeNode=node
end

function V:SetAlpha(pin,alpha)
  if not pin then return end
  alpha=tonumber(alpha) or 1
  if pin.fullNode then alpha=alpha*0.85 end
  if alpha<0 then alpha=0 end
  if alpha>1 then alpha=1 end

  if pin.texture then
    pin.texture:SetVertexColor(pin.iconR or 1,pin.iconG or 1,pin.iconB or 1,alpha)
  end
  if pin.glowTexture and pin.glowTexture:IsShown() then
    pin.glowTexture:SetVertexColor(pin.glowR or 1,pin.glowG or 1,pin.glowB or 1,alpha)
  end
end
