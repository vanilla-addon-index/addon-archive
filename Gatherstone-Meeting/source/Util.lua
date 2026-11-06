function string.startswith(str, start)
    return string.sub(str, 1, string.len(start)) == start
end

function string.isempty(s)
    return s == nil or s == ''
end

function string.meetingsplit(str, delimiter)
    if not str then
        return nil
    end
    local delimiter, fields = delimiter or ":", {}
    local pattern = string.format("([^%s]+)", delimiter)
    string.gsub(str, pattern, function(c)
        fields[table.getn(fields) + 1] = c
    end)
    return unpack(fields)
end

-- 添加字符串trim函数 by 武藤纯子酱 2025.12.30
function string.trim(str)
    if not str then return "" end
    return string.gsub(str, "^%s*(.-)%s*$", "%1")
end
