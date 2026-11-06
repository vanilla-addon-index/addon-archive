AshenDB = AshenDB or {}
AshenDB.Items = AshenDB.Items or {}
AshenDB.ItemOrder = AshenDB.ItemOrder or {}
AshenDB.Version = "0.1.0"

function AshenDB:GetItem(id)
    return self.Items[tonumber(id)]
end

function AshenDB:GetItemCount()
    if self.Manifest and self.Manifest.itemCount then return self.Manifest.itemCount end
    return table.getn(self.ItemOrder)
end

function AshenDB:FindItems(text, slot, maxResults)
    text = string.lower(text or "")
    maxResults = maxResults or 50
    local out = {}
    for _, id in ipairs(self.ItemOrder) do
        local item = self.Items[id]
        if item and (not slot or item[3] == slot) then
            local name = string.lower(item[1] or "")
            if text == "" or string.find(name, text, 1, true) then
                table.insert(out, id)
                if table.getn(out) >= maxResults then break end
            end
        end
    end
    return out
end

AshenDB.ItemDetails = AshenDB.ItemDetails or {}
AshenDB.ItemSources = AshenDB.ItemSources or {}

AshenDB.ItemSets = AshenDB.ItemSets or {}

function AshenDB:GetSetCount()
    local count = 0
    local _
    for _ in pairs(self.ItemSets or {}) do count = count + 1 end
    return count
end

function AshenDB:GetSourceItemCount()
    local count = 0
    local _
    for _ in pairs(self.ItemSources or {}) do count = count + 1 end
    return count
end
