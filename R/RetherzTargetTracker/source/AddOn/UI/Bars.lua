local BarHeight = 60;
local BarWidth = 240;
local Padding = 3;
local Border = 3;

local nextUpdate = 0;


function RTT_CreateGUI()
  RTT_CreateGUIFrame();
  RTT_CreateBars();
end

function RTT_CreateGUIFrame()
  local f = CreateFrame("Frame", "RTT_Frame", UIParent);
  f:SetWidth((BarWidth + Border * 2));
  f:SetHeight((BarHeight * 8 + Padding * 7 + Border * 2));
  RTT_Frame:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", RetherzTargetTracker.X, RetherzTargetTracker.Y);
  f:SetScale(RetherzTargetTracker.Scale / 100);
  if(not RetherzTargetTracker.Visible) then
    f:Hide();
  end

	f:SetScript("OnMouseDown", function()
	  if not RTT_Frame.isMoving then
	     RTT_Frame:StartMoving();
	   RTT_Frame.isMoving = true;
   	 RTT_Frame:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background"});
	  end
	end)
	RTT_Frame:SetScript("OnMouseUp", function()
	  if RTT_Frame.isMoving then
	   RTT_Frame:StopMovingOrSizing();
	   RTT_Frame.isMoving = false;
     --local _, _, _, x, y = RTT_Frame:GetPoint();
     local x,y = RTT_Frame:GetRight(), RTT_Frame:GetTop();
     RetherzTargetTracker.X = x;
     RetherzTargetTracker.Y = y;
	  end
	end)
	RTT_Frame:SetScript("OnHide", function()
	  if ( RTT_Frame.isMoving ) then
	   RTT_Frame:StopMovingOrSizing();
	   RTT_Frame.isMoving = false;
   	 RTT_Frame:SetBackdrop(nil);
	  end
  end)
	f:SetBackdropColor(1,1,1,1);
end

function RTT_CreateBars()
  for i=1, 8 do
    local f = CreateFrame("Frame", "RTT_Bar" .. i, RTT_Frame);
    f:SetWidth((BarWidth));
    f:SetHeight((BarHeight));
    f:SetPoint("TOPLEFT", Border, -(Border + ((BarHeight + Padding) * (8 - i))));
  	f:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background"});
    f:SetAlpha(0.5);
  	f:SetBackdropColor(0,0,0,1);
    RTT_SetTrackedDebuffs();
    RTT_CreateBarSymbolTexture(f, i);
    RTT_CreateBarHealthLabel(f, i);
    RTT_CreateBarNameLabel(f, i);
    RTT_CreateBarDebuffTextures(f, i);
    local button = CreateFrame("Button", "RTT_Bar" .. i .. "Button", f);
    button.target = i;
  	button:SetPoint("TOPLEFT", Border, 0);
    button:SetWidth((BarWidth));
    button:SetHeight((BarHeight));
      button:SetScript("OnClick", function (self)
        RTT_Target(button.target);
      end);
  end
  RTT_Frame:SetScript("OnUpdate", function(self)
    if(GetTime() >= nextUpdate) then
      nextUpdate = GetTime() + 1;
    else
      return
    end
    RTT_TestTarget();
    RTT_SpellCastSent();
    RTT_UpdateHealth();
    RTT_DebuffTestTarget();
    for bar=1,8 do
      if(RTT_Symbols[bar].state) then
        for debuff=1,RetherzTargetTracker.DebuffCount do
          RTT_Bar_DebuffUpdate(bar, debuff);
        end
      end
    end
  end)

  --DEBUG
  for z=1, RetherzTargetTracker.DebuffCount do
    RTT_SetTrackedDebuff(z, RTT_TrackedDebuffs[z]);
  end
end

function RTT_CreateBarSymbolTexture(parent, i)
  local f = parent:CreateTexture("RTT_Bar" .. i .. "SymbolTexture", "ARTWORK");
	f:SetPoint("TOPLEFT", Padding, -Padding);
	f:SetTexture("Interface/TargetingFrame/UI-RaidTargetingIcons");
  f:SetTexCoord(RTT_TexCoord(i));
	f:SetHeight((BarHeight - Padding * 2));
	f:SetWidth((BarHeight - Padding * 2));
end

function RTT_CreateBarHealthLabel(parent, i)
  local f = parent:CreateFontString("RTT_Bar" .. i .. "HealthLabel", "OVERLAY", "GameFontHighlightLarge");
	f:SetPoint("TOPLEFT", BarHeight  - Padding * 3, -Padding * 3);
	f:SetHeight((BarHeight - Padding * 2));
	f:SetWidth((BarHeight - Padding * 2));
	f:SetJustifyH("RIGHT");
end

function RTT_CreateBarNameLabel(parent, i)
  local f = parent:CreateFontString("RTT_Bar" .. i .. "NameLabel", "OVERLAY", "GameFontNormalSmall");
	f:SetPoint("TOPLEFT", BarHeight, -Padding);
	f:SetHeight((BarHeight - Padding * 2) / 3);
	f:SetWidth((BarWidth - (BarHeight - Padding * 2)));
	f:SetJustifyH("LEFT");
end

function RTT_CreateBarDebuffTextures(parent, i)
  for n=1, RetherzTargetTracker.DebuffCount do
    local f = parent:CreateTexture("RTT_Bar" .. i .. "DebuffTexture" .. n, "ARTWORK");
  	f:SetPoint("TOPLEFT", BarHeight + Padding * 7 + n * (BarHeight / 2), -(BarHeight / 2 - Padding * 3));
    f:SetHeight((BarHeight / 2.2));
    f:SetWidth((BarHeight / 2.2));
    f:SetAlpha(0.25);
    RTT_CreateBarDebuffLabel(parent, i, n, BarHeight + Padding * 7 + n * (BarHeight / 2), -(BarHeight / 2 - Padding * 3));
  end
end

function RTT_CreateBarDebuffLabel(parent, i, n, xOffset, yOffset)
  local f = parent:CreateFontString("RTT_Bar" .. i .. "DebuffTextureLabel" .. n, "OVERLAY", "GameFontNormalSmall");
	f:SetPoint("TOPLEFT", xOffset - ((BarHeight / 2.2) / 4), yOffset + Padding * 3 - (BarHeight / 2.2));
  f:SetHeight((BarHeight / 2.2));
  f:SetWidth((BarHeight / 2.2));
	f:SetJustifyH("RIGHT");
end
