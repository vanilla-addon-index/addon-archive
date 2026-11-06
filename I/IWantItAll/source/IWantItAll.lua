BINDING_HEADER_IWIA = "I Want It All"

BINDING_NAME_IWIA_NEXT = "Next Tracking"

function IWIA_Print(msg)
   DEFAULT_CHAT_FRAME:AddMessage(msg, 1.0, 0.9, 0.1)
end

local textures = {
    ["Interface\\Icons\\INV_Misc_Flower_02"] = "Find Herbs",
    ["Interface\\Icons\\Racial_Dwarf_FindTreasure"] = "Find Treasure",
    ["Interface\\Icons\\Spell_Nature_Earthquake"] = "Find Minerals",
    ["Interface\\Icons\\inv_tradeskillitem_03"] = "Find Trees",
    ["Interface\\Icons\\INV_Misc_Fish_02"] = "Find Fish",
    ["Interface\\Icons\\INV_Misc_Fish_28"] = "Find Fish"
}

local cmds = {
    ["herbs"] = "Find Herbs",
    ["chests"] = "Find Treasure",
    ["ores"] = "Find Minerals",
    ["trees"] = "Find Trees",
    ["fish"] = "Find Fish"
}

local function skip(id)
    return (IWIA_Settings[id] or {}).skip
end

local queue = nil
local firstId = nil
local info = nil

function IWIA_Scan()
    if queue then
        return
    end
    IWIA_Settings = IWIA_Settings or {}
    queue = {}
    info = {}
    firstId = nil
    local prevId = nil
    local _, _, offset, numSpells = GetSpellTabInfo(1)
    for s = offset + 1, offset + numSpells do
        local texture = GetSpellTexture(s, BOOKTYPE_SPELL)
        local name, _ = GetSpellName(s, BOOKTYPE_SPELL)
        local id = textures[texture]
        if id then
            if not skip(id) then
                firstId = firstId or id
                queue[id] = {
                    slot = s,
                    nextId = firstId
                }
                local prev = queue[prevId]
                if prev then
                    prev.nextId = id
                end
                prevId = id
            end
            info[id] =  {
                name = name,
                texture = texture,
                slot = s,
            }
        end
    end

end

function IWIA_Rescan()
    queue = nil
    IWIA_Scan()
end

function IWIA_OnSpellChanged()
    IWIA_Rescan()
end

function IWIA_Next()
    IWIA_Scan()
    local id = textures[GetTrackingTexture()]
    local nextId = id and (queue[id] or {}).nextId or firstId
    if not nextId then
        return
    end
    local slot = queue[nextId].slot
    local _, duration, _ = GetSpellCooldown(slot, BOOKTYPE_SPELL)
    if duration == 0 then --"Not ready yet" spam prevention
        CastSpell(slot, BOOKTYPE_SPELL)
    end

end

function IWIA_Help()
    IWIA_Scan()
    IWIA_Print("/iwia next - to change tracking")
    for cmd, id in pairs(cmds) do
        local known = info[id]
        local skip = skip(id)
        local on = (known and not skip) and "|cFF00FF00on|r" or "on"
        local off = (known and skip) and "|||cFFFF0000off|r" or "|off"
        IWIA_Print("/iwia "..cmd.." "..on..off)
    end
end

function IWIA_SlashCmd(cmd)
    local _, _, cmd, arg1, arg2 = string.find(cmd, "(%w+)%s*(%w*)%s*(%w*)")
    if cmd == "next" then
        IWIA_Next()
    elseif cmds[cmd] then
        local id = cmds[cmd]
        IWIA_Settings[id] = IWIA_Settings[id] or {}
        if arg1 == "on" then
            IWIA_Settings[id].skip = false
        elseif arg1 == "off" then
            IWIA_Settings[id].skip = true
        else
            IWIA_Help()
        end
        IWIA_Rescan()
    else
        IWIA_Help()
    end
end

function IWIA_OnLoad()
   SLASH_IWIA1 = "/iwia"
   SLASH_IWIA2 = "/iwantitall"
   SlashCmdList.IWIA = IWIA_SlashCmd
end
