-- Variables
ShouldUseAoe = false
local lastAoECheck = 0
local AUTO_AOE_THRESHOLD = 3 -- Number of enemies to trigger auto-AoE
local MAX_ENEMY_SCAN_DISTANCE = 20 -- Yards to scan for enemies
local Threat_AoE_ManualOverride = false
local RevengeReadyUntil = 0;

function Threat_Configuration_Init()
    if (not Threat_Configuration) then
        Threat_Configuration = { }
    end

    if (Threat_Configuration["Debug"] == nil) then
        Threat_Configuration["Debug"] = false
    end
    
    -- Initialize manual override CVar
    if GetCVar("Threat_AoE_ManualOverride") == nil then
        SetCVar("Threat_AoE_ManualOverride", "0")
    end
end

-- Normal Functions


function CountNearbyEnemies()
    local enemyCount = 0
    
    -- Check player's target first
    if UnitExists("target") and UnitCanAttack("player", "target") then
        enemyCount = enemyCount + 1
    end
    
    -- Check party/raid members' targets
    if GetNumRaidMembers() > 0 then
        -- In raid
        for i = 1, GetNumRaidMembers() do
            local unit = "raid"..i.."target"
            if UnitExists(unit) and UnitCanAttack("player", unit) and not UnitIsUnit("target", unit) then
                if CheckInteractDistance(unit, 3) then -- 3 = about 20 yards
                    enemyCount = enemyCount + 1
                    if enemyCount >= AUTO_AOE_THRESHOLD then
                        return enemyCount
                    end
                end
            end
        end
    else
        -- In party
        for i = 1, GetNumPartyMembers() do
            local unit = "party"..i.."target"
            if UnitExists(unit) and UnitCanAttack("player", unit) and not UnitIsUnit("target", unit) then
                if CheckInteractDistance(unit, 3) then -- 3 = about 20 yards
                    enemyCount = enemyCount + 1
                    if enemyCount >= AUTO_AOE_THRESHOLD then
                        return enemyCount
                    end
                end
            end
        end
    end
    
    return enemyCount
end

local function Print(msg)
  local coloredMessage = "|c00FFFF00"..msg.."|r"
  if (not DEFAULT_CHAT_FRAME) then
    return;
  end
  DEFAULT_CHAT_FRAME:AddMessage(coloredMessage);
end

local function Debug(msg)
  if (Threat_Configuration["Debug"]) then
    if (not DEFAULT_CHAT_FRAME) then
      return;
    end
    DEFAULT_CHAT_FRAME:AddMessage(msg);
  end
end

--------------------------------------------------

function SpellId(spellname)
  local id = 1;
  for i = 1, GetNumSpellTabs() do
    local _, _, _, numSpells = GetSpellTabInfo(i);
    for j = 1, numSpells do
      local spellName = GetSpellName(id, BOOKTYPE_SPELL);
      if (spellName == spellname) then
        return id;
      end
      id = id + 1;
    end
  end
  return nil;
end

function SpellReady(spellname)
  local id = SpellId(spellname);
  if (id) then
    local start, duration = GetSpellCooldown(id, 0);
    if (start == 0 and duration == 0 and ThreatLastSpellCast + 1 <= GetTime()) then
      return true;
    end
  end
  return nil;
end

function HasBuff(unit, texturename)
  local id = 1;
  while (UnitBuff(unit, id)) do
    local buffTexture = UnitBuff(unit, id);
    if (string.find(buffTexture, texturename)) then
      return true;
    end
    id = id + 1;
  end
  return nil;
end

function HasDebuff(unit, texturename)
  local id = 1
  local debuffTexture = UnitDebuff(unit, id)
  while debuffTexture do
    if string.find(debuffTexture, texturename) then
      return true
    end
    id = id + 1
    debuffTexture = UnitDebuff(unit, id)
  end
  return false
end

function ActiveStance()
  for i = 1, 3 do
    local _, _, active = GetShapeshiftFormInfo(i);
    if (active) then
      return i;
    end
  end
  return nil;
end

function HasFiveSunderArmors(unit)
  local id = 1;
  while (UnitDebuff(unit, id)) do
    local debuffTexture, debuffAmount = UnitDebuff(unit, id);
    if (string.find(debuffTexture, "Sunder")) then
      if (debuffAmount >= 5) then
        return true;
      else
        return nil;
      end
    end
    id = id + 1;
  end
  return nil;
end

function RevengeAvail()
  if GetTime() < RevengeReadyUntil then
    return true;
  else
    return nil;
  end
end

-- taken from https://github.com/allfoxwy/Threat
function RageCost(spellName)
    -- Must do this SetOwner in this function, or tooltip would be blank
    ThreatTooltip:SetOwner(UIParent, "ANCHOR_NONE");

    local spellID = SpellId(spellName);
    if not spellID then
        -- if we can't find this spell in book, we return a huge cost so we won't use it
        Debug("Can't find " .. spellName .. " in book");
        return 9999;
    end

    ThreatTooltip:SetSpell(spellID, BOOKTYPE_SPELL);

    local lineCount = ThreatTooltip:NumLines();

    for i = 1, lineCount do
        local leftText = getglobal("ThreatTooltipTextLeft" .. i);

        if leftText:GetText() then
            local _, _, rage = string.find(leftText:GetText(), RAGE_DESCRIPTION_REGEX_THREAT);

            if rage then
                return tonumber(rage);
            end
        end
    end

    -- Spells like taunt doesn't cost rage, they dont have rage cost in description
    return 0;
end


function Threat()
  if (not UnitIsCivilian("target")) then
    local class = UnitClass("player")
    if (class == CLASS_WARRIOR_THREAT) then
      WarriorThreat();
    elseif (class == CLASS_PALADIN_THREAT) then
      PaladinThreat();
    elseif (class ==CLASS_DRUID_THREAT) then
      DruidThreat();
    end
  end
end

function WarriorThreat()
  local rage = UnitMana("player");
  local revengeCost = RageCost(ABILITY_REVENGE_THREAT);
  local apCost = RageCost(ABILITY_BATTLE_SHOUT_THREAT);
  local hsCost = RageCost(ABILITY_HEROIC_STRIKE_THREAT);
  local shieldSlamCost = RageCost(ABILITY_SHIELD_SLAM_THREAT);

  if (ActiveStance() ~= 2) then
    Debug("Changing to def stance");
    CastSpellByName(ABILITY_DEFENSIVE_STANCE_THREAT);
  end

  if (SpellReady(ABILITY_REVENGE_THREAT) and RevengeAvail() and rage >= revengeCost) then
    Debug("Revenge");
    CastSpellByName(ABILITY_REVENGE_THREAT);
  elseif (ShouldStackSunder and SpellReady(ABILITY_SUNDER_ARMOR_THREAT)
          and not HasDebuff("targe", "Ability_Warrior_Riposte")
          and not HasFiveSunderArmors("target")) then
    Debug("Sunder armor");
    CastSpellByName(ABILITY_SUNDER_ARMOR_THREAT);
  elseif (ShouldBuffShout and SpellReady(ABILITY_BATTLE_SHOUT_THREAT) and not HasBuff("player", "Ability_Warrior_BattleShout") and rage >= apCost) then
    Debug("Battle Shout");
    CastSpellByName(ABILITY_BATTLE_SHOUT_THREAT);
  elseif (SpellReady(ABILITY_SHIELD_SLAM_THREAT) and rage >= shieldSlamCost) then
    Debug("Shield slam");
    CastSpellByName(ABILITY_SHIELD_SLAM_THREAT);
  elseif (SpellReady(ABILITY_HEROIC_STRIKE_THREAT) and rage >= (shieldSlamCost + hsCost)) then
    Debug("Heroic strike");
    CastSpellByName(ABILITY_HEROIC_STRIKE_THREAT);
  elseif (SpellReady(ABILITY_SUNDER_ARMOR_THREAT) and rage >= 80) then
    Debug("Sunder armor");
    CastSpellByName(ABILITY_SUNDER_ARMOR_THREAT);
  end
end

function PaladinThreat()
  if (not HasBuff("player", "Spell_Holy_SealOfFury")) then
    CastSpellByName(ABILITY_RIGHTEOUS_FURY);
  end

  if (not HasBuff("player", "Spell_Holy_DivineIntervention") and SpellReady(ABILITY_HOLY_SHIELD)) then
    Debug("Holy Shield");
    CastSpellByName(ABILITY_HOLY_SHIELD);
  end

  if (ShouldJudgementWisdom and not HasDebuff("target", "Spell_Holy_RighteousnessAura")) then
    Debug("Target has no Judgement of Wisdom");
    if (HasBuff("player", "Spell_Holy_RighteousnessAura")) then
      Debug("Judgement of Wisdom");
      CastSpellByName(ABILITY_JUDGEMENT);
    else
      Debug("Seal of Wisdom");
      CastSpellByName(ABILITY_SEAL_OF_WISDOM);
    end
  end

  if (SpellReady(ABILITY_HOLY_STRILE)) then
    Debug("Holy Strike");
    CastSpellByName(ABILITY_HOLY_STRILE);
  end

  if (not HasBuff("player", "Ability_ThunderBolt")) then
    CastSpellByName(ABILITY_SEAL_OF_RIGHTEOUSNESS)
  end

  if (SpellReady(ABILITY_JUDGEMENT) and HasBuff("player", "Ability_ThunderBolt")) then
    Debug("Judgement of Righteousness")
    CastSpellByName(ABILITY_JUDGEMENT)
  end
end

function DruidThreat()
    local rage = UnitMana("player")
    
    -- Auto-AoE detection (throttled to check once per second)
    if GetTime() - lastAoECheck > 1.0 then
        local enemyCount = CountNearbyEnemies()
        local shouldAutoAoe = enemyCount >= AUTO_AOE_THRESHOLD
        
        -- Only auto-switch if not manually overridden
        if shouldAutoAoe ~= ShouldUseAoe and not Threat_AoE_ManualOverride then
            ShouldUseAoe = shouldAutoAoe
            if Threat_Configuration["Debug"] then
                Debug("Auto-AoE: "..(ShouldUseAoe and "ON" or "OFF").." ("..enemyCount.." enemies)")
            end
        end
        
        lastAoECheck = GetTime()
    end
  -- Enter Bear Form if not already
  if (ActiveStance() ~= 1) then
    Debug("Changing to bear form");
    CastShapeshiftForm(1)
    return
  end

  -- AOE MODE
  if ShouldUseAoe then
    if (SpellReady(ABILITY_SWIPE) and rage >= RageCost(ABILITY_SWIPE)) then
      Debug("Swipe")
      CastSpellByName(ABILITY_SWIPE)
      return
    end

    -- Use Demoralizing Roar if not already applied
    if (SpellReady(ABILITY_DEMORALIZING_ROAR) and not HasDebuff("target", "Ability_Druid_DemoralizingRoar")) then
      Debug("Demoralizing Roar")
      CastSpellByName(ABILITY_DEMORALIZING_ROAR)
      return
    end

    -- Backup: Maul a main target if excess rage
    if (SpellReady(ABILITY_MAUL) and rage >= RageCost(ABILITY_MAUL)) then
      Debug("Maul (AoE backup)")
      CastSpellByName(ABILITY_MAUL)
      return
    end

    return -- End AoE logic
  end

  -- SINGLE-TARGET MODE

  -- Use Faerie Fire (Feral) if not on cooldown or applied
  if (SpellReady(ABILITY_FAERIE_FIRE) and not HasDebuff("target", "Spell_Nature_FaerieFire")) then
    Debug("Faerie Fire (Feral)")
    CastSpellByName(ABILITY_FAERIE_FIRE)
    return
  end

  -- Use Growl if aggro is lost
  if (UnitExists("targettarget") and UnitName("targettarget") ~= UnitName("player")) then
    if SpellReady(ABILITY_GROWL) then
      Debug("Growl (Taunt)")
      CastSpellByName(ABILITY_GROWL)
      return
    end
  end

  -- Savage Bite
if (HasBuff("player", "Spell_Shadow_ManaBurn") and SpellReady(ABILITY_SAVAGE_BITE)) then
    Debug("Savage Bite")
    CastSpellByName(ABILITY_SAVAGE_BITE)
    return
  end

  -- Maul - main threat filler
  if (SpellReady(ABILITY_MAUL) and rage >= RageCost(ABILITY_MAUL)) then
    Debug("Maul")
    CastSpellByName(ABILITY_MAUL)
    return
  end

  -- Swipe as backup single-target filler
  if (SpellReady(ABILITY_SWIPE) and rage >= RageCost(ABILITY_SWIPE)) then
    Debug("Swipe (backup)")
    CastSpellByName(ABILITY_SWIPE)
    return
  end

  -- Demoralizing Roar utility if needed
  if (SpellReady(ABILITY_DEMORALIZING_ROAR) and not HasDebuff("target", "Ability_Druid_DemoralizingRoar")) then
    Debug("Demoralizing Roar")
    CastSpellByName(ABILITY_DEMORALIZING_ROAR)
    return
  end
end

-- Chat Handlers

function Threat_SlashCommand(msg)
  local _, _, command, options = string.find(msg, "([%w%p]+)%s*(.*)$");
  if (command) then
    command = string.lower(command);
  end
  if (command == nil or command == "") then
    Threat();
  elseif (command == "shout") then
    if (ShouldBuffShout) then
      ShouldBuffShout = false
      Print(SLASH_THREAT_SHOUT .. ": " .. SLASH_THREAT_DISABLED)
    else
      ShouldBuffShout = true
      Print(SLASH_THREAT_SHOUT .. ": " .. SLASH_THREAT_ENABLED)
    end
  elseif (command == "sunder") then
    if (ShouldStackSunder) then
      ShouldStackSunder = false
      Print(SLASH_THREAT_SUNDER .. ": " .. SLASH_THREAT_DISABLED)
    else
      ShouldStackSunder = true
      Print(SLASH_THREAT_SUNDER .. ": " .. SLASH_THREAT_ENABLED)
    end
  elseif (command == "wisdom") then
    if (ShouldJudgementWisdom) then
      ShouldJudgementWisdom = false
      Print(SLASH_THREAT_WISDOM .. ": " .. SLASH_THREAT_DISABLED)
    else
      ShouldJudgementWisdom = true
      Print(SLASH_THREAT_WISDOM .. ": " .. SLASH_THREAT_ENABLED)
    end

    elseif (command == "aoe") then
        if (ShouldUseAoe) then
            ShouldUseAoe = false
            Threat_AoE_ManualOverride = true
            Print("AoE mode: Disabled (Manual)")
        else
            ShouldUseAoe = true
            Threat_AoE_ManualOverride = true
            Print("AoE mode: Enabled (Manual)")
        end

  elseif (command == "debug") then
    if (Threat_Configuration["Debug"]) then
      Threat_Configuration["Debug"] = false;
      Print(BINDING_HEADER_THREAT .. ": " .. SLASH_THREAT_DEBUG .. " " .. SLASH_THREAT_DISABLED .. ".")
    else
      Threat_Configuration["Debug"] = true;
      Print(BINDING_HEADER_THREAT .. ": " .. SLASH_THREAT_DEBUG .. " " .. SLASH_THREAT_ENABLED .. ".")
    end
  else
    Print(SLASH_THREAT_HELP_GENERAL)
    Print(SLASH_THREAT_HELP_GENERAL_WARRIOR)
    Print(SLASH_THREAT_HELP_HELP)
    Print(SLASH_THREAT_HELP_SUNDER)
    Print(SLASH_THREAT_HELP_SHOUT)
    Print(SLASH_THREAT_HELP_GENERAL_PALADIN)
    Print(SLASH_THREAT_HELP_WISDOM)
  end
end
-- Event Handlers

function Threat_OnLoad()
  this:RegisterEvent("VARIABLES_LOADED");
  this:RegisterEvent("PLAYER_ENTER_COMBAT");
  this:RegisterEvent("PLAYER_LEAVE_COMBAT");
  this:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES");

  ThreatLastSpellCast = GetTime();
  ThreatLastStanceCast = GetTime();
  SlashCmdList["THREAT"] = Threat_SlashCommand;
  SLASH_THREAT1 = "/threat";
end

function Threat_OnEvent(event)
  if (event == "VARIABLES_LOADED") then
    Threat_Configuration_Init()
  elseif (event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES")then
    if string.find(arg1,"You block")
    or string.find(arg1,"You parry")
    or string.find(arg1,"You dodge") then
      Debug("Revenge soon ready");
      RevengeReadyUntil = GetTime() + 4;
    end
  end
end
