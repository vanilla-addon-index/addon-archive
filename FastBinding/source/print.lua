FBPrint = {}

FBPrint.Colors = {
    ["red"]    = {1.0, 0.0, 0.0},
    ["green"]  = {0.0, 1.0, 0.0},
    ["blue"]   = {0.0, 0.0, 1.0},
    ["yellow"] = {1.0, 1.0, 0.0},
    ["cyan"]   = {0.0, 1.0, 1.0},
    ["magenta"]= {1.0, 0.0, 1.0},
    ["white"]  = {1.0, 1.0, 1.0},
    ["gray"]   = {0.5, 0.5, 0.5},
    ["black"]  = {0.0, 0.0, 0.0},
    ["orange"] = {1.0, 0.5, 0.0},
    ["purple"] = {0.5, 0.0, 0.5},
}

function FBPrint.Chat(msg, color)
    local c = FBPrint.Colors[color] or FBPrint.Colors["gray"]
	ChatFrame1:AddMessage("FastBinding - "..msg, c[1], c[2], c[3])
end

function FBPrint.Debug(msg, color)
    if FastBinding.Debug then
        local c = FBPrint.Colors[color] or FBPrint.Colors["red"]
	    ChatFrame1:AddMessage("[DEBUG] - "..msg, c[1], c[2], c[3])
    end
end