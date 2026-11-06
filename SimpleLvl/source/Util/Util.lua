local _G = _G or getfenv(0)
local SL = _G.SimpleLvl

function SL.util:RegisterForEvent(event, callback, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
	if not self.eventFrame then
		self.eventFrame = CreateFrame("Frame")
		self.eventFrame:SetScript("OnEvent", function()
            local e = event
            local store = this.events[e]
            if store then
                for func, args in pairs(store) do
                    func(unpack(args), arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
                end
            end
		end)
        self.eventFrame.events = {}
	end
    local frame = self.eventFrame
    frame.events[event] = frame.events[event] or {}
    frame.events[event][callback] = {arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8}

	self.frame:RegisterEvent(event)
end

function SL.util.Colorize(text, r, g, b)
    if type(r) == "table" then
        r = r[1]
        g = g[2]
        b = b[3]
    end
    return "|cFF" .. string.format("%02x%02x%02x", r * 255, g * 255, b * 255) .. text .. "|r"
end

function SL.util.SecondsToTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor(math.mod(seconds, 3600) / 60)
    local s = math.floor(math.mod(seconds, 60))
    return h, m, s
end

--[[ function SL.util.GetCommand(msg)
    if msg then
        local a, b, c = string.find(msg, "(%S+)");
        if a then
            return c, string.find(msg, b + 2);
        else
            return "";
        end
    end
end ]]

function SL.util.GetCommand(msg)
    if msg then
        local a, b, command = string.find(msg, "(%S+)")
        if command then
            local subCommand = string.sub(msg, b + 2)
            return command, subCommand
        end
    end
    return "", ""
end