--[[
  Created by Vee (http://victortemprano.com), Drixi in-game
  See Github repo at https://github.com/tempranova/turtlerp
]]

function TurtleRP.IconTrayMover(actionType, frame)
  if not frame then
    return
  end
  local newLeft = frame:GetLeft() or 0
  local newTop = frame:GetTop() or 0
  if actionType == "mousedown" then
    TurtleRP.movingIconTray = {
      left = newLeft,
      top = newTop
    }
  else
    if type(TurtleRP.movingIconTray) == "table"
      and (TurtleRP.movingIconTray.left ~= newLeft or TurtleRP.movingIconTray.top ~= newTop) then
      TurtleRP.movingIconTray = true
    else
      TurtleRP.movingIconTray = nil
    end
  end
end

function TurtleRP.BindFrameToWorldFrame(frame)
	if not frame or not UIParent or not WorldFrame then
		return
	end
	local scale = UIParent:GetEffectiveScale() or 1
	frame:SetParent(WorldFrame)
	frame:SetScale(scale)
end

function TurtleRP.BindFrameToUIParent(frame)
	if not frame or not UIParent then
		return
	end
	frame:SetParent(UIParent)
	frame:SetScale(1)
end

function TurtleRP.EnableRPMode()
	TurtleRP.BindFrameToWorldFrame(GameTooltip);
	TurtleRP.BindFrameToWorldFrame(ChatFrameEditBox);
	TurtleRP.BindFrameToWorldFrame(ChatFrameMenuButton);
	TurtleRP.BindFrameToWorldFrame(ChatMenu);
	TurtleRP.BindFrameToWorldFrame(EmoteMenu);
	TurtleRP.BindFrameToWorldFrame(LanguageMenu);
	TurtleRP.BindFrameToWorldFrame(VoiceMacroMenu);
	TurtleRP.BindFrameToWorldFrame(TurtleRP_IconTray)
	TurtleRP.BindFrameToWorldFrame(TurtleRP_ChatBox)
	--TurtleRP.BindFrameToWorldFrame(TurtleRPInfobox);

	for i = 1, 7 do
		TurtleRP.BindFrameToWorldFrame(getglobal("ChatFrame" .. i));
		TurtleRP.BindFrameToWorldFrame(getglobal("ChatFrame" .. i .. "Tab"));
	end

	TurtleRP.RPMode = 1;
	CloseAllWindows();
	UIParent:Hide();
end

function TurtleRP.DisableRPMode()
	TurtleRP.BindFrameToUIParent(GameTooltip);
	GameTooltip:SetFrameStrata("TOOLTIP");
	TurtleRP.BindFrameToUIParent(ChatFrameEditBox);
	ChatFrameEditBox:SetFrameStrata("DIALOG");
	TurtleRP.BindFrameToUIParent(ChatFrameMenuButton);
	ChatFrameMenuButton:SetFrameStrata("DIALOG");
	TurtleRP.BindFrameToUIParent(ChatMenu);
	ChatMenu:SetFrameStrata("DIALOG");
	TurtleRP.BindFrameToUIParent(EmoteMenu);
	EmoteMenu:SetFrameStrata("DIALOG");
	TurtleRP.BindFrameToUIParent(LanguageMenu);
	LanguageMenu:SetFrameStrata("DIALOG");
	TurtleRP.BindFrameToUIParent(VoiceMacroMenu);
	VoiceMacroMenu:SetFrameStrata("DIALOG");
	TurtleRP.BindFrameToUIParent(TurtleRP_IconTray)
	TurtleRP.BindFrameToUIParent(TurtleRP_ChatBox)
	--TurtleRP.BindFrameToUIParent(TurtleRPInfobox);

	for i = 1, 7 do
		TurtleRP.BindFrameToUIParent(getglobal("ChatFrame" .. i));
		TurtleRP.BindFrameToUIParent(getglobal("ChatFrame" .. i .. "Tab"));
	end

	TurtleRP.RPMode = 0;
	UIParent:Show();
end
