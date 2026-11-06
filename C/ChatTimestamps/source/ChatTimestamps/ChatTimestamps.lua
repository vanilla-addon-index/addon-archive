-- ChatTimestamps by Skizo
--

local CTS_MainFrame;

function ChatTimestamps_ChatFrame_AddMessage(self, msg, a1,a2,a3,a4,a5,a6,a7,a8,a9)
  return self:ChatTimestamps_Orig_AddMessage(ChatTimestamps_AddTimeStamp(msg),a1,a2,a3,a4,a5,a6,a7,a8,a9);
end

function ChatTimestamps_Trim(s)
   return string.gsub(s, "^%s*(.-)%s*$", "%1");
end

function ChatTimestamps_OnEvent()
             if not (ChatTimestampsSettings) then
               -- Default Settings
               ChatTimestampsSettings               = { };
               ChatTimestampsSettings.Format        = "[%H:%M:%S]";
             end

             ChatTimestamps_HookAllChatFrames();
end

function ChatTimestamps_OnLoad()

        -- Register the slash command
        SlashCmdList["CHATTIMESTAMPS"] = function(msg)
          ChatTimestamps_SlashCommand(msg);
        end;
        SLASH_CHATTIMESTAMPS1 = "/chattimestamps";
        SLASH_CHATTIMESTAMPS2 = "/cts";

        CTS_MainFrame = CreateFrame("Frame", "ChatTimestampsFrame");
        CTS_MainFrame:SetScript("OnEvent", ChatTimestamps_OnEvent);
        CTS_MainFrame:RegisterEvent("VARIABLES_LOADED");

           if( DEFAULT_CHAT_FRAME ) then
               DEFAULT_CHAT_FRAME:AddMessage("|cffffff00ChatTimestamps 1.6a loaded");
           else
               UIErrorsFrame:AddMessage("ChatTimestamps AddOn loaded", 1.0, 1.0, 1.0, 1.0, UIERRORS_HOLD_TIME);
           end

end

function ChatTimestamps_HookAllChatFrames()
  for i=1,NUM_CHAT_WINDOWS do
    local cf = getglobal("ChatFrame"..i);
    cf.ChatTimestamps_Orig_AddMessage = cf.AddMessage;
    cf.AddMessage = ChatTimestamps_ChatFrame_AddMessage;
  end
end

function ChatTimestamps_AddTimeStamp(msg)
	if not (msg == nil) then
          local locFormat = ChatTimestampsSettings.Format;
          if (strfind(locFormat,"#H") ~= 1) then
            local ParsedTime = date("%H");
            if (strsub(ParsedTime,1,1) == "0") then ParsedTime = strsub(ParsedTime,2); end;
            locFormat = gsub(locFormat, "#H", ParsedTime);
          end
          if (strfind(locFormat,"#I") ~= 1) then
            local ParsedTime = date("%I");
            if (strsub(ParsedTime,1,1) == "0") then ParsedTime = strsub(ParsedTime,2); end;
            locFormat = gsub(locFormat, "#I", ParsedTime);
          end
	  msg = date(locFormat).." "..msg;  -- TimeStamp Format
	end
	return msg;
end

function ChatTimestamps_SlashCommand(msg)

        -- Check the command
        if (msg) then
                local command = ChatTimestamps_Trim(msg);
                local params = "";

                if (strfind(command," ") ~= nul) then
                  command = strsub(command,0,strfind(command," ")-1);
                  params  = ChatTimestamps_Trim(strsub(msg,strfind(msg,command)+strlen(command)));
                  command = strlower(command);
                end

                if (command == "status") then
                        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00ChatTimestamps Format: "..ChatTimestampsSettings.Format);

                elseif ((command == "format") and (strlen(params) > 0)) then
                        params = string.gsub(params, "||", "|");
                        ChatTimestampsSettings.Format = params;
                        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00ChatTimestamps Format set to: \""..ChatTimestampsSettings.Format.."\"");

                else
                        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00ChatTimestamps Options:");
                        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00/cts status - Shows current settings");
                        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00/cts format <timeformat> (default \"[%H:%M:%S]\") - Sets timestamp format");
                end
        end
end

ChatTimestamps_OnLoad();