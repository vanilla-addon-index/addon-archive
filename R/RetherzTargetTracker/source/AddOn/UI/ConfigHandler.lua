function RTT_HandleConfig()
  SLASH_RTT1 = "/rtt";
  SLASH_RTT2 = "/retherztargettracker";
  SlashCmdList["RTT"] = RTT_ConfigGUIToggle;
  RetherzTargetTracker = RetherzTargetTracker ~= nil and RetherzTargetTracker or {};
  if(RetherzTargetTracker.Visible == nil) then
    RetherzTargetTracker.Visible = true;
  end
  RetherzTargetTracker.Scale = RetherzTargetTracker.Scale ~= nil and RetherzTargetTracker.Scale or 100;
  RetherzTargetTracker.X = RetherzTargetTracker.X ~= nil and RetherzTargetTracker.X or math.floor(((GetScreenWidth() + 246) / 2) / (RetherzTargetTracker.Scale / 100));
  RetherzTargetTracker.Y = RetherzTargetTracker.Y ~= nil and RetherzTargetTracker.Y or math.floor(((GetScreenHeight() + 507 ) / 2) / (RetherzTargetTracker.Scale / 100));
  RetherzTargetTracker.UseAction = RetherzTargetTracker.UseAction ~= nil and RetherzTargetTracker.UseAction or 0;
  RetherzTargetTracker.DebuffCount = RetherzTargetTracker.DebuffCount ~= nil and RetherzTargetTracker.DebuffCount or 4;
  RetherzTargetTracker.Debuff1 = RetherzTargetTracker.Debuff1 ~= nil and RetherzTargetTracker.Debuff1 or "Sunder Armor";
  RetherzTargetTracker.Debuff2 = RetherzTargetTracker.Debuff2 ~= nil and RetherzTargetTracker.Debuff2 or "Faerie Fire";
  RetherzTargetTracker.Debuff3 = RetherzTargetTracker.Debuff3 ~= nil and RetherzTargetTracker.Debuff3 or "Curse of Recklessness";
  RetherzTargetTracker.Debuff4 = RetherzTargetTracker.Debuff4 ~= nil and RetherzTargetTracker.Debuff4 or "Armor Shatter";
end

function RTT_SetTrackedDebuffs()
  RTT_TrackedDebuffs[1] = RetherzTargetTracker.Debuff1;
  RTT_TrackedDebuffs[2] = RetherzTargetTracker.Debuff2;
  RTT_TrackedDebuffs[3] = RetherzTargetTracker.Debuff3;
  RTT_TrackedDebuffs[4] = RetherzTargetTracker.Debuff4;
end

function RTT_StoreDebuffs()
  RetherzTargetTracker.Debuff1 = RTT_TrackedDebuffs[1];
  RetherzTargetTracker.Debuff2 = RTT_TrackedDebuffs[2];
  RetherzTargetTracker.Debuff3 = RTT_TrackedDebuffs[3];
  RetherzTargetTracker.Debuff4 = RTT_TrackedDebuffs[4];
end
