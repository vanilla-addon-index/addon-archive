-- BossTactics - Logic File

BossTactics = {};

-------------------------------------------------
-- SLASH COMMANDS
-------------------------------------------------

SLASH_BOSSTACTICS1 = "/bosstactics";
SLASH_BOSSTACTICS2 = "/bt";
SlashCmdList["BOSSTACTICS"] = function(msg)
    BossTactics:CommandHandler(msg);
end;

-- Main command handler
function BossTactics:CommandHandler(msg)
    local args = self:GetArgs(msg);
    local command = table.remove(args, 1);

    if (not command) or (command == "help") then
        self:PrintHelp();
        return;
    end

    local raidName = command;
    local bossName = table.remove(args, 1);
    local tacticName = table.concat(args, " ");

    if not (raidName and bossName and tacticName and tacticName ~= "") then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000BossTactics Error:|r Invalid format. Use /bt help");
        return;
    end

    self:PostTactic(raidName, bossName, tacticName);
end

-- Finds and posts a specific tactic to Raid Warning
function BossTactics:PostTactic(raidName, bossName, tacticName)
    local tacticText;

    if not self.Data then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000BossTactics Error:|r Data file not loaded correctly.");
        return;
    end

    for rName, bosses in pairs(self.Data) do
        if string.lower(rName) == string.lower(raidName) then
            for bName, tactics in pairs(bosses) do
                if string.lower(bName) == string.lower(bossName) then
                    for tName, text in pairs(tactics) do
                        if string.lower(tName) == string.lower(tacticName) then
                            tacticText = text;
                            break;
                        end
                    end
                end
                if tacticText then break; end
            end
        end
        if tacticText then break; end
    end

    if tacticText then
        SendChatMessage(tacticText, "RAID_WARNING");
        -- Optional: uncomment the line below if you want a local confirmation message.
        -- DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BossTactics:|r Posted: " .. tacticText);
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000BossTactics Error:|r Tactic not found for: " .. raidName .. " > " .. bossName .. " > " .. tacticName);
    end
end

-- Prints help information to the chat frame
function BossTactics:PrintHelp()
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BossTactics Commands:|r");
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/bt <Raid> <Boss> <Tactic>|r");
    DEFAULT_CHAT_FRAME:AddMessage("    - Posts a tactic to Raid Warning.");
    DEFAULT_CHAT_FRAME:AddMessage("    - Use quotes for names with spaces.");
    DEFAULT_CHAT_FRAME:AddMessage("    - |cffaaaaaaExample:|r /bt \"Molten Core\" Lucifron Curse");
end

-- Argument parser
function BossTactics:GetArgs(str)
    local args = {};
    if not str or str == "" then return args end

    local inQuotes = false;
    local currentArg = "";

    -- Add a space at the end to ensure the last argument is captured
    str = str .. " ";

    for i = 1, string.len(str) do
        local char = string.sub(str, i, i);

        if char == "\"" then
            inQuotes = not inQuotes;
        elseif char == " " and not inQuotes then
            if string.len(currentArg) > 0 then
                table.insert(args, currentArg);
                currentArg = "";
            end
        else
            currentArg = currentArg .. char;
        end
    end
    return args;
end

-- Announce that the addon is loaded
DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BossTactics (Simple)|r loaded. Use |cffffff00/bt help|r for commands.");
