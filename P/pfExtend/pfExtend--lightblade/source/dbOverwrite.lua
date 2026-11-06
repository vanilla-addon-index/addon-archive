
local function overwrite(type, id, data)
    if pfDB[type]["data"][id] then
        pfDB[type]["data"][id] = data
    end
end
do -- area trigger
end

do -- items
    overwrite("items", 30017, { ["U"] = { [10184] = 2.5 } })
    overwrite("items", 30018, { ["U"] = { [60748] = 2.5 } })
end

do -- units/npcs
end

do -- quests

end
