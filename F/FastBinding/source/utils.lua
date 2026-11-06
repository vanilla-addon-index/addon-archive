function IsInArray(key, array)
    if array[key] then
        return true
    else
        return false
    end
end

function SplitActionButton(str)
    local i = string.len(str)
    local num = ""

    while i > 0 do
        local c = string.sub(str, i, i)
        if string.find(c, "%d") then
            num = c .. num
            i = i - 1
        else
            break
        end
    end

    if num ~= "" then
        local base = string.sub(str, 1, i)
        return base, tonumber(num)
    else
        return str, nil
    end
end
