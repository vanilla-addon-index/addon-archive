------------------------------------------------------------------------------------------------------
-- Arcanum

-- Addon for Mage inspired by the famous Necrosis
-- Management of buffs, portals and Component Counter

-- Thanks to the authors of Necrosis

-- Author Lenny415
-- Reworked by Fayz for Turtle WoW
------------------------------------------------------------------------------------------------------
-- Functions taken from Necrosis - THANK YOU to their authors




------------------------------------------------------------------------------------------------------
-- DISPLAY FUNCTIONS (CONSOLE, CHAT, SYSTEM MESSAGE)
------------------------------------------------------------------------------------------------------


function Arcanum_Msg(msg, type)
	if (msg and type) then
		-- Si le type du message est "USER", le message s'affiche sur l'cran...
		if (type == "USER") then
			-- On colorise astucieusement notre message :D
			msg = Arcanum_MsgAddColor(msg);
			local Intro = Arcanum_ColoredMsg("Arcanum").."|CFFFFFFFF: ";
			if ArcanumConfig.ChatType then
				-- ...... sur la première fenêtre de chat
				ChatFrame1:AddMessage(Intro..msg, 1.0, 0.7, 1.0, 1.0, UIERRORS_HOLD_TIME);
			else
				-- ...... ou au milieu de l'écran
				UIErrorsFrame:AddMessage(Intro..msg, 1.0, 0.7, 1.0, 1.0, UIERRORS_HOLD_TIME);
			end
		-- Si le type du message est "WORLD", le message sera envoyé en raid,  défaut en groupe, et  défaut en chat local
		elseif (type == "WORLD") then
			if (GetNumRaidMembers() > 0) then
				SendChatMessage(msg, "RAID");
			elseif (GetNumPartyMembers() > 0) then
				SendChatMessage(msg, "PARTY");
			else
				SendChatMessage(msg, "SAY");
			end
        elseif (type == "WORLD2") then
            UIErrorsFrame:AddMessage(Arcanum_ColoredMsg(msg), 1.0, 0.7, 1.0, 1.0, UIERRORS_HOLD_TIME);
			if (GetNumRaidMembers() > 0) then
				SendChatMessage(msg, "RAID");
			elseif (GetNumPartyMembers() > 0) then
				SendChatMessage(msg, "PARTY");
			end    
		-- Si le type du message est "PARTY", le message sera envoyé en groupe
		elseif (type == "PARTY") then
			SendChatMessage(msg, "PARTY");
		-- Si le type du message est "RAID", le message sera envoyé en raid
		elseif (type == "RAID") then
			SendChatMessage(msg, "RAID");
		elseif (type == "SAY") then
		-- Si le type du message est "SAY", le message sera envoyé en chat local
			SendChatMessage(msg, "SAY");
		end
	end
end


------------------------------------------------------------------------------------------------------
-- ... AND THE COLORAMA WAS BORN!
------------------------------------------------------------------------------------------------------

function Arcanum_ColoredMsg(msg)
    --  50 à B0
    local pre = "|CFF00";
    local post = "FF";
    local msg2 = "";
    local color = 96;
    local pitch = 80/string.len(msg);
    for i = 1, string.len(msg) do
        if (string.sub(msg,i,i) ~= "\195" and string.sub(msg,i,i) ~= "\194") then
            msg2 = msg2..pre..IntToHex(math.ceil(color))..post..string.sub(msg,i,i);
            color = color + pitch;
        else
            msg2 = msg2..pre..IntToHex(math.ceil(color))..post..string.sub(msg,i,i+1);
            color = color + pitch;
            i = i+1;
        end
    end
    return msg2;
end

function IntToHex(value)
    local a = math.ceil(value/16);
    a = string.gsub(a, 10, "A");
    a = string.gsub(a, 11, "B");
    a = string.gsub(a, 12, "C");
    a = string.gsub(a, 13, "D");
    a = string.gsub(a, 14, "E");
    a = string.gsub(a, 15, "F");
    local b = math.mod (value, 16);
    b = string.gsub(b, 10, "A");
    b = string.gsub(b, 11, "B");
    b = string.gsub(b, 12, "C");
    b = string.gsub(b, 13, "D");
    b = string.gsub(b, 14, "E");
    b = string.gsub(b, 15, "F");
    return a..b;
end

-- Replaces color codes in strings with associated color definitions
function Arcanum_MsgAddColor(msg)
	msg = string.gsub(msg, "<white>", "|CFFFFFFFF");
	msg = string.gsub(msg, "<lightBlue>", "|CFF99CCFF");
	msg = string.gsub(msg, "<brightGreen>", "|CFF00FF00");
	msg = string.gsub(msg, "<lightGreen2>", "|CFF66FF66");
	msg = string.gsub(msg, "<lightGreen1>", "|CFF99FF66");
	msg = string.gsub(msg, "<yellowGreen>", "|CFFCCFF66");
	msg = string.gsub(msg, "<lightYellow>", "|CFFFFFF66");
	msg = string.gsub(msg, "<darkYellow>", "|CFFFFCC00");
	msg = string.gsub(msg, "<lightOrange>", "|CFFFFCC66");
	msg = string.gsub(msg, "<dirtyOrange>", "|CFFFF9933");
	msg = string.gsub(msg, "<darkOrange>", "|CFFFF6600");
	msg = string.gsub(msg, "<redOrange>", "|CFFFF3300");
	msg = string.gsub(msg, "<red>", "|CFFFF0000");
	msg = string.gsub(msg, "<lightRed>", "|CFFFF5555");
	msg = string.gsub(msg, "<lightPurple1>", "|CFFFFC4FF");
	msg = string.gsub(msg, "<lightPurple2>", "|CFFFF99FF");
	msg = string.gsub(msg, "<purple>", "|CFFFF50FF");
	msg = string.gsub(msg, "<darkPurple1>", "|CFFFF00FF");
	msg = string.gsub(msg, "<darkPurple2>", "|CFFB700B7");
	msg = string.gsub(msg, "<close>", "|r");
	return msg;
end


-- Inserts color codes in timers based on remaining time percentage
function ArcanumTimerColor(percent)
	local color = "<brightGreen>";
	if (percent < 10) then
		color = "<red>";
	elseif (percent < 20) then
		color = "<redOrange>";
	elseif (percent < 30) then
		color = "<darkOrange>";
	elseif (percent < 40) then
		color = "<dirtyOrange>";
	elseif (percent < 50) then
		color = "<darkYellow>";
	elseif (percent < 60) then
		color = "<lightYellow>";
	elseif (percent < 70) then
		color = "<yellowGreen>";
	elseif (percent < 80) then
		color = "<lightGreen1>";
	elseif (percent < 90) then
		color = "<lightGreen2>";
	end
	return color;
end

------------------------------------------------------------------------------------------------------
-- USER-FRIENDLY VARIABLES IN SUMMONING MESSAGES
------------------------------------------------------------------------------------------------------

function Arcanum_MsgReplace(msg, dest)
	msg = string.gsub(msg, "<me>", UnitName("player"));
    if UnitSex("player") == 2 then
        msg = string.gsub(msg, "<me2>", "he");
    elseif UnitSex("player") == 3 then
        msg = string.gsub(msg, "<me2>", "she");
    end
	if dest then
		if ArcanumConfig.IsAlliance then
			msg = string.gsub(msg, "<city>", ALLIANCE_DEST[dest]);
		else
			msg = string.gsub(msg, "<city>", HORDE_DEST[dest]);
		end
	end
	return msg;
end
