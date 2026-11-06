HBPowerInfusion = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceDebug-2.0", "AceEvent-2.0", "AceModuleCore-2.0", "AceHook-2.1","CandyBar-2.0")
HBPowerInfusion:SetModuleMixins("AceDebug-2.0")
Waterfall = AceLibrary("Waterfall-1.0")

local MEDIAPATH = "Interface\\Addons\\HBPowerInfusion\\Media\\"
local TEXTURES = {"Aluminium","BantoBar","Luna","Otravi","Smooth"}
local BARS = "HBPowerInfusion_CandyBarGroup"
local SOUND_ALERT_POWERINFUSION = "PowerInfusion.wav"
local SOUND_ALERT_ARCANEPOWER = "ArcanePower.wav"
local SOUND_ALERT_REFRESHSHADOW = "RefreshShadow.wav"
local SOUND_ALERT_RESISTED = "Resisted.wav"

local COOLDOWN_0_MESSAGE = "PI is ready"
local COOLDOWN_30_MESSAGE = "PI ready in 30 seconds"

local lastWhisperTime = 0
local lastArcanePower = 0
local lastShadowVulnResist = 0

BINDING_HEADER_HBPOWERINFUSION = "HB PowerInfusion"
BINDING_NAME_HBPI_POWERINFUSION = "Power Infusion"
BINDING_NAME_HBPI_SETFOCUS = "Set PI Focus"

local PI_ALERT_BUFFS = {
  ["Massive Destruction"] = 20,
  ["Arcane Potency"] = 20,
  ["Mind Quickening"] = 20,
  ["Nature Aligned"] = 20,
  ["Ascendance"] = 20,
  ["Ephemeral Power"] = 15,
  ["Essence of Sapphiron"] = 20,
  ["Unstable Power"] = 20,
  ["Chromatic Infusion"] = 15,
  ["Obsidian Insight"] = 30,
  ["Pagle's Broken Reel"] = 15,
  ["Combustion"] = 15, -- Combustion duration actually lasts until the mage does 3 crits, but that's shit for our purposes so lets just say 15s
  ["Arcane Power"] = 15,
  ["Power Infusion"] = 15,
  ["Shadow Vulnerability"] = 15,
}

local BUFF_COLOR_DEFAULT = "green"
local BUFF_COLORS = {
  ["Arcane Power"] = "red",
  ["Power Infusion"] = "yellow",
  ["Shadow Vulnerability"] = "magenta",
}

function HBPowerInfusion:OnInitialize()
  self:RegisterDB("HBPowerInfusionDB",nil,"char")
  self:RegisterDefaults("profile", self:GetDefaultDB())
  self:RegisterChatCommand( { "/hbpowerinfusion" , "/hbpi" } , self.ShowGUI )
  self.OnMenuRequest = self.BuildOptions
  local opt = self:BuildOptions()
  opt.name = "General Options"
  Waterfall:Register(self.title, "aceOptions", opt)
  HBAddOnMenu:RegisterAddOn(self)
  self:InitBars()
end

function HBPowerInfusion:SoundAlert(alert)
  if self.db.profile.soundAlert then
    local success = PlaySoundFile(MEDIAPATH .. alert)
    if not success then
      self:ScheduleEvent("HBPI_SOUNDALERT_"..alert,function() self:SoundAlert(alert) end, 0.1)
    end
  end
end

function HBPowerInfusion:OnEnable()
  self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS", function() self:ParseBuff() end)
  self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS", function() self:ParseBuff() end)
  self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS", function() self:ParseBuff() end)
  self:RegisterEvent("CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF", function() self:ShadowSpellCheck() end)
  self:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE", function() self:ShadowSpellCheck() end)
  self:RegisterEvent("CHAT_MSG_WHISPER")
  
  if self.db.profile.shadowWeavingEnabled and IsAddOnLoaded("Chronometer") then
    self:Hook(Chronometer,"StartTimer","ChronometerTimerHook" )
  end
end


function HBPowerInfusion:CHAT_MSG_WHISPER()
  if arg2 == self.db.profile.pifocus then
    if string.find(arg1,"[pP][iI]") == 1 then
      self:SoundAlert(SOUND_ALERT_POWERINFUSION)
    end
  end
end

function HBPowerInfusion:ParseBuff()
  local _,_,unit,buff = string.find(arg1, "(.+) gains? (.+)\.")
  if not (unit and buff) then
    return
  end
  if unit == "You" then
    unit = UnitName("player")
  end
  if unit == self.db.profile.pifocus and PI_ALERT_BUFFS[buff] then
    self:Alert(buff)
  end
end

function HBPowerInfusion:Alert(buff)
  if not PI_ALERT_BUFFS[buff] then
    return
  end
  local name = string.gsub(buff, "%s", "_")
  if name == "Arcane_Power" then
    lastArcanePower = GetTime()
    self:SoundAlert(SOUND_ALERT_ARCANEPOWER)
  elseif name == "Shadow_Vulnerability" or name == "Power_Infusion" then
    -- do nothing
  elseif lastArcanePower < GetTime() - 14 then
    self:SoundAlert(SOUND_ALERT_POWERINFUSION)
  end
  self:NewBar(name,buff,PI_ALERT_BUFFS[buff],BUFF_COLORS[buff] or BUFF_COLOR_DEFAULT)
end

function HBPowerInfusion:ShowGUI()
  Waterfall:Open(HBPowerInfusion.title)
end

function HBPowerInfusion:GetDefaultDB()
  local defaultdb = {
    lock = true,
    framePos = {
      x = 300,
      y = -300,
      h = 15,
      w = 160,
    },
    fontsize = 12,
    barTexture = "Luna",
    growup = false,
    lock = false,
    whisperMessage = "POWER INFUSION ON YOU",
    soundAlert = true,
    cooldownNotify = true,
    cooldown0message = COOLDOWN_0_MESSAGE,
    cooldown30message = COOLDOWN_30_MESSAGE,
    refreshShadowTime = 5,
    shadowWeavingEnabled = false,
  }
  return defaultdb
end

function HBPowerInfusion:PowerInfusion()
  if self.db.profile.pifocus~=nil then
    local clear,last
    if not UnitExists("target") then
      clear = true
    elseif UnitName("target")~= self.db.profile.pifocus then
      last = true
    end
    TargetByName(self.db.profile.pifocus,true)
    CastSpellByName("Power Infusion")
    self:ScheduleEvent(function() self:PowerInfusionInform() end,1)
    if clear then
      ClearTarget()
    elseif last then
      TargetLastTarget()
    end
    UIErrorsFrame:AddMessage("Power Infusing " .. self.db.profile.pifocus)
  else
    UIErrorsFrame:AddMessage("No PI Focus set")
  end
end

function HBPowerInfusion:SetPIFocus()
  local oldFocus = self.db.profile.pifocus
  self.db.profile.pifocus=UnitName("target")
  if self.db.profile.pifocus~=nil then
    UIErrorsFrame:AddMessage(self.db.profile.pifocus.." is PI Focus")
    if self.db.profile.pifocus ~= oldFocus then
      lastArcanePower = 0
    end
  else
    UIErrorsFrame:AddMessage("PI Focus unset")
  end
end

local function FindBuff(obuff,unit)
  local buff = strlower(obuff)
  local tooltip = HB_Tooltip or CreateFrame("GameTooltip", "HB_Tooltip", nil, "GameTooltipTemplate")
  tooltip:Hide()
  local textleft1 = getglobal(tooltip:GetName().."TextLeft1")
  if ( not unit ) then
    unit ='player'
  end
  for i = 1,32 do
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetUnitBuff(unit, i)
    b = textleft1:GetText()
    if ( b and strfind(strlower(b), buff) ) then
      return "buff", i, b
    elseif not b then
      break
    end
  end
  for i= 1,32 do
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetUnitDebuff(unit, i)
    b = textleft1:GetText()
    if ( b and strfind(strlower(b), buff) ) then
      return "debuff", i, b
    elseif not b then
      break
    end
  end
end

function HBPIFindBuff(obuff,unit)
  return FindBuff(obuff,unit)
end

function HBPowerInfusion:PowerInfusionInform()
  if lastWhisperTime and lastWhisperTime > GetTime() - 30 then
    return
  end
  local clear,last
  if not UnitExists("target") then
    clear = true
  elseif UnitName("target")~= self.db.profile.pifocus then
    last = true
  end
  TargetByName(self.db.profile.pifocus)
  if FindBuff("Power Infusion","target") then
    SendChatMessage(self.db.profile.whisperMessage,"WHISPER",nil,self.db.profile.pifocus)
    lastWhisperTime = GetTime()
    if self.db.profile.cooldownNotify then
      self:ScheduleEvent(function() SendChatMessage(self.db.profile.cooldown30message or COOLDOWN_30_MESSAGE,"WHISPER",nil,self.db.profile.pifocus) end, 149)
      self:ScheduleEvent(function() SendChatMessage(self.db.profile.cooldown0message or COOLDOWN_0_MESSAGE,"WHISPER",nil,self.db.profile.pifocus) end, 179)
    end
  end
  if clear then
    ClearTarget()
  elseif last then
    TargetLastTarget()
  end
end

function HBPowerInfusion:InitBars()
  self.anchor = CreateFrame("FRAME",nil,UIParent)
  self.anchor.texture = self.anchor:CreateTexture(nil,"BACKGROUND")
  self.anchor.text = self.anchor:CreateFontString(nil,"BACKGROUND","GameFontNormal")
  self.anchor.text:SetPoint("CENTER",self.anchor,"CENTER",0,0)
  self.anchor.text:SetText("HB Power Infusion")
  self.anchor.texture:SetTexture(0,0,0,0.5)
  self.anchor.texture:SetAllPoints()
  self.anchor:EnableMouse()
  self.anchor:SetScript("onMouseDown", function()
    this:SetMovable(true)
    this:StartMoving()
  end)
  self.anchor:SetScript("onMouseUp", function()
    this:StopMovingOrSizing()
    this:SetMovable(false)
    local _,_,_,x,y = this:GetPoint()
    self.db.profile.framePos.x = x
    self.db.profile.framePos.y = y
    self:RefreshBars()
  end)
  self:RegisterCandyBarGroup(BARS)  
  self:RefreshBars()
end

function HBPowerInfusion:RefreshBars()
  self.anchor:Show()
  self.anchor:ClearAllPoints()
  self.anchor:SetPoint("TOPLEFT","UIParent","TOPLEFT", self.db.profile.framePos.x, self.db.profile.framePos.y )
  self.anchor:SetWidth(self.db.profile.framePos.w)
  self.anchor:SetHeight(self.db.profile.framePos.h)
  self:SetCandyBarGroupPoint(BARS, "RIGHT", self.anchor, "RIGHT", 0,0)
  self:SetCandyBarGroupGrowth(BARS,self.db.profile.growup)
  if self.db.profile.lock then
    self.anchor:Hide()
  end
end

function HBPowerInfusion:NewBar(name,text,seconds,color)
  if not text then
    text = name
  end
  self:RegisterCandyBar(name,seconds,text,nil,color)
  self:SetCandyBarHeight(name,self.anchor:GetHeight())
  self:SetCandyBarWidth(name,self.anchor:GetWidth())
  self:SetCandyBarTexture(name,MEDIAPATH .. self.db.profile.barTexture)
  self:SetCandyBarFontSize(name,self.db.profile.fontsize)
  self:SetCandyBarBackgroundColor(name,"black",0.2)
  self:RegisterCandyBarWithGroup(name,BARS)
  self:StartCandyBar(name,true)
end

local function TestBarFunc(testbar)
  return function() HBPowerInfusion:Alert(testbar) end
end

-- SHADOW WEAVING
function HBPowerInfusion:ShadowSpellCheck()
  if not self.db.profile.shadowWeavingEnabled then
    return
  end
  local name = string.gfind(arg1,"Your Mind Blast hits (.+) for ")()
  if not name then
    name = string.gfind(arg1,"Your Mind Blast crits (.+) for ")()
  end
  if name then
    self:ScheduleEvent(function() self:CompleteMindBlast(name) end, 0.5)
  else
    name = string.gfind(arg1,"Your (.+) was resisted")()
    if name then
      local resistAlert
      if name == "Shadow Vulnerability" then
        lastShadowVulnResist = GetTime()
        resistAlert = true
      elseif name == "Mind Blast" or name == "Shadow Word: Pain" then
        resistAlert = true
      end
      if resistAlert then
        self:SoundAlert(SOUND_ALERT_RESISTED)
      end
    end
  end
end

function HBPowerInfusion:CompleteMindBlast(name)
  self:ChronometerTimerHook(Chronometer, Chronometer.timers[Chronometer.EVENT]["ShadowVulnDummy"],"ShadowVulnDummy",name,nil,-0.25)
end

function HBPowerInfusion:ChronometerTimerHook(chronometer, timer, name, target, rank, durmod)
  if name=="ShadowVulnDummy" then
    if lastShadowVulnResist < GetTime() - 1 then
      name = "Shadow Vulnerability"
      self:NewBar(name,target,15+(durmod or 0),BUFF_COLORS["Shadow Vulnerability"])
      self:OnShadowWeave(target)
    end
  else
    self.hooks[Chronometer].StartTimer(chronometer, timer, name, target, rank, durmod)
  end
end

function HBPowerInfusion:OnShadowWeave(target)
  if UnitName("target") == target then
    for i = 1,16 do
      local icon,stack = UnitDebuff("target",i)
      if stack then
        if icon == "Interface\\Icons\\Spell_Shadow_BlackPlague" then
          self:SoundAlert(stack..".wav")
          break
        end
      else
        break
      end
    end
  end
  self:ScheduleEvent("HBPI_SOUNDALERT_REFRESHSHADOW",function() self:SoundAlert(SOUND_ALERT_REFRESHSHADOW) end, 14.5 - self.db.profile.refreshShadowTime )
end

-- MENU

function HBPowerInfusion:BuildOptions()
  local menu = {
    type = "group",
    args = {
      lock = {
        type = "toggle",
        name = "Lock Bar Anchor",
        desc = "Locks the bar anchor",
        get = function() return self.db.profile.lock end,
        set = function(v)
          self.db.profile.lock = v
          self:RefreshBars()
        end,
        order = 1,
      },
      w = {
        type = "range",
        name = "Bar Width",
        desc = "Width of bars",
        get = function() return self.db.profile.framePos.w end,
        set = function(v)
          self.db.profile.framePos.w = v
          self:RefreshBars()
        end,
        min = 50, max = 300, step = 1,
        order = 101,
      },
      h = {
        type = "range",
        name = "Bar Height",
        desc = "Height of bars",
        get = function() return self.db.profile.framePos.h end,
        set = function(v)
          self.db.profile.framePos.h = v
          self:RefreshBars()
        end,
        min = 5, max = 50, step = 1,
        order = 102,
      },
      texture = {
        type = "text",
        name = "Bar Texture",
        desc = "Set the Texture to be used for bars",
        get = function() return self.db.profile.barTexture end,
        set = function(v)
          self.db.profile.barTexture = v
          self:RefreshBars()
        end,
        validate = TEXTURES,
        order = 103,
      },
      growth = {
        type = "toggle",
        name = "Grow upwards",
        desc = "Sets whether the bar group grows up or down",
        get = function() return self.db.profile.growup end,
        set = function(v)
          self.db.profile.growup = v
          self:RefreshBars()
        end,
        order = 201,
      },
      fontsize = {
        type = "range",
        name = "Font Size",
        desc = "Sets font size of bar text",
        get = function() return self.db.profile.fontsize end,
        set = function(v)
          self.db.profile.fontsize = v
          self:RefreshBars()
        end,
        min = 6, max = 32, step = 1,
        order = 203,
      },
      whisperMessage = {
        type = "text",
        name = "Whisper Message",
        desc = "Sets the text which is whispered to the target when you use Power Infusion",
        get = function() return self.db.profile.whisperMessage end,
        set = function(v)
          self.db.profile.whisperMessage = v
          self:Print("Whisper message set to: \"" .. self.db.profile.whisperMessage .. "\"")
        end,
        usage = "<text>",
        validate = function(s) return string.len(s) > 0 end,
        order = 301,
      },
      soundAlert = {
        type = "toggle",
        name = "Sound Alerts",
        desc = "Sets whether Sound Alerts are played when PI Focus gains relevant buffs.  A \"Power Infusion\" alert will be played when the focus gains a relevant buff, and does not have Arcane Power.  An \"Arcane Power\" alert wil be played when the target gain Arcane Power.",
        get = function() return self.db.profile.soundAlert end,
        set = function(v) self.db.profile.soundAlert = v end,
        order = 302,
      },
      cooldownNotify = {
        type = "toggle",
        name = "Cooldown Notifications",
        desc = "Sets whether notifications will be sent to your focus when your PI cooldown finishes, or has 30 seconds remaining.",
        get = function() return self.db.profile.cooldownNotify end,
        set = function(v) self.db.profile.cooldownNotify = v end,
        order = 303,
      },
      cooldown0message = {
        type = "text",
        name = "Cooldown Finished Message",
        desc = "Sets the text which is whispered to the target when your PI cooldown finishes",
        get = function() return self.db.profile.cooldown0message end,
        set = function(v)
          self.db.profile.cooldown0message = v
          self:Print("Cooldown Finished message set to: \"" .. self.db.profile.cooldown0message .. "\"")
        end,
        usage = "<text>",
        validate = function(s) return string.len(s) > 0 end,
        order = 304,
      },
      cooldown30message = {
        type = "text",
        name = "Cooldown 30s Message",
        desc = "Sets the text which is whispered to the target when your PI cooldown has 30s remaining",
        get = function() return self.db.profile.cooldown30message end,
        set = function(v)
          self.db.profile.self.db.profile.cooldown30message = v
          self:Print("Cooldown 30s message set to: \"" .. self.db.profile.cooldown30message .. "\"")
        end,
        usage = "<text>",
        validate = function(s) return string.len(s) > 0 end,
        order = 305,
      },
      shadowWeavingEnabled = {
        type = "toggle",
        name = "Shadow Weaving",
        desc = "Enable Shadow Weaving alerts and events",
        get = function() return self.db.profile.shadowWeavingEnabled end,
        set = function(v) self.db.profile.shadowWeavingEnabled = v end,
        order = 401,
      },
      refreshShadowTime = {
        type = "range",
        name = "Shadowweave Refresh Time",
        desc = "Seconds before Shadow Vulnerability expiration that soundalert will be played",
        get = function() return self.db.profile.refreshShadowTime end,
        set = function(v) self.db.profile.refreshShadowTime = v end,
        order = 402,
        min = 1,max = 12,step = 0.5,
      },
      test = {
        type = "group",
        name = "Test Bars",
        desc = "Create some test bars",
        args = {},
        order = 10001,
      },
      reset = {
        type = "execute",
        name = "Reset to Defaults",
        desc = "Resets all options to default values",
        func = function()
          self.db.profile = self:GetDefaultDB()
          self:RefreshBars()
        end,
        order = 10002,
      },
    }
  }
  for k,testbar in pairs({"Mind Quickening","Arcane Power","Power Infusion","Shadow Vulnerability"}) do
    local testBarFunc = TestBarFunc(testbar)
    menu.args.test.args[string.gsub(testbar,"%s","_")] = {
      type = "execute",
      name = testbar,
      desc = "Start the " .. testbar .. " test bar",
      func = testBarFunc,
    }
  end
  return menu
end