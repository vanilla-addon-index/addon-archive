-- Freewood-OctoWoW-Codex: Probe /fwquest
-- Prueft auf Octo, was der Server zu einer Quest-ID liefert (C_QuestLog.GetQuestDetails) und ob sich die darin
-- genannten Kreaturen, Objekte und Items ueber ihre ID benennen lassen. Nur Diagnose: schreibt in den Chat und nach
-- Codex.db.questProbe (SavedVariables, erst bei /reload oder Abmelden), veraendert keine Daten der Datenbank.
--
--   /fwquest              prueft ein paar bekannte Quests (7, 6, 3904, 1467)
--   /fwquest <ID> [...]   prueft diese Quest-IDs
--   /fwquest go <ID>      prueft ein Spielobjekt (C_GameObjectInfo)
--   /fwquest npc <ID>     prueft eine Kreatur (C_CreatureInfo)

local ADDON, NS = ...

local FW = _G.Freewood
local Codex = NS and NS.Codex
if not FW or not Codex then
    return
end

local Probe = {}
Codex.QuestProbe = Probe

local WAIT = 3

local function Store()
    local db = Codex.db
    if not db then return nil end
    db.questProbe = db.questProbe or {}
    return db.questProbe
end

local function Short(v)
    local s = tostring(v)
    s = s:gsub("|", "/"):gsub("\n", " ")
    if #s > 120 then s = s:sub(1, 120) .. "..." end
    return s
end

-- Tabelle als Zeilen "pfad = wert"
local function Flatten(t, path, out, depth)
    if depth > 3 then out[#out + 1] = path .. " = {...}" return end
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
        local v = t[k]
        local p = path == "" and tostring(k) or (path .. "." .. tostring(k))
        if type(v) == "table" then
            Flatten(v, p, out, depth + 1)
        else
            out[#out + 1] = p .. " = " .. Short(v)
        end
    end
end

local function Say(text) FW:Print("Quest-Probe: " .. text) end

local function Log(rec, line)
    rec[#rec + 1] = line
    Say(line)
end

local function Call(fn, a)
    if type(fn) ~= "function" then return false, "fehlt" end
    return pcall(fn, a)
end

local function ItemName(id)
    local CI = _G.C_Item
    local get = (CI and CI.GetItemInfo) or _G.GetItemInfo
    if not get then return nil end
    local ok, name = pcall(get, id)
    if ok and type(name) == "string" and name ~= "" then return name end
    return nil
end

local function CreatureName(id)
    local CC = _G.C_CreatureInfo
    if not (CC and CC.GetCreatureInfoByID) then return nil end
    local ok, info = pcall(CC.GetCreatureInfoByID, id)
    if ok and type(info) == "table" then
        return tostring(info.name) .. " (Typ " .. tostring(info.type) .. ", Rang " .. tostring(info.rank) .. (info.subName and info.subName ~= "" and (", " .. info.subName) or "") .. ")"
    end
    return nil
end

local function ObjectName(id)
    local CG = _G.C_GameObjectInfo
    if not (CG and CG.GetGameObjectInfoByID) then return nil end
    local ok, info = pcall(CG.GetGameObjectInfoByID, id)
    if ok and type(info) == "table" then
        return tostring(info.name) .. " (Typ " .. tostring(info.type) .. ", Anzeige " .. tostring(info.displayID) .. ")"
    end
    return nil
end

local function RequestNames(details)
    local CC, CG, CI = _G.C_CreatureInfo, _G.C_GameObjectInfo, _G.C_Item
    local function Req(fn, id) if fn then pcall(fn, id) end end
    for _, r in ipairs(details.requirements or {}) do
        if r.kind == "monster" then Req(CC and CC.RequestLoadCreatureByID, r.id)
        elseif r.kind == "object" then Req(CG and CG.RequestLoadGameObjectByID, r.id)
        elseif r.kind == "item" then Req(CI and CI.RequestLoadItemDataByID, r.id) end
    end
    for _, list in ipairs({ details.rewardItems or {}, details.choiceItems or {} }) do
        for _, it in ipairs(list) do Req(CI and CI.RequestLoadItemDataByID, it.id) end
    end
    if (details.srcItemID or 0) > 0 then Req(CI and CI.RequestLoadItemDataByID, details.srcItemID) end
end

local function ReportDetails(id, rec, d)
    local lines = {}
    Flatten(d, "", lines, 0)
    Log(rec, "Quest " .. id .. ": " .. #lines .. " Felder")
    for _, l in ipairs(lines) do rec[#rec + 1] = "  " .. l end
    Say(string.format("%s | Stufe %s | Typ %s | Geld %s | Ziele %d | feste Items %d | Wahl-Items %d | Ort %s",
        Short(d.title), tostring(d.level), tostring(d.questType or "-"), tostring(d.rewardMoney),
        #(d.requirements or {}), #(d.rewardItems or {}), #(d.choiceItems or {}),
        d.poi and (tostring(d.poi.mapID) .. ":" .. tostring(d.poi.x) .. "," .. tostring(d.poi.y)) or "-"))
end

local function ReportNames(id, rec, d)
    for _, r in ipairs(d.requirements or {}) do
        local name
        if r.kind == "monster" then name = CreatureName(r.id)
        elseif r.kind == "object" then name = ObjectName(r.id)
        else name = ItemName(r.id) end
        Log(rec, string.format("  Ziel %s %d x%s -> %s", r.kind, r.id, tostring(r.count), name or "kein Name (noch nicht geladen)"))
    end
    for _, def in ipairs({ { "feste Belohnung", d.rewardItems }, { "Wahl-Belohnung", d.choiceItems } }) do
        for _, it in ipairs(def[2] or {}) do
            Log(rec, string.format("  %s Item %d x%s -> %s", def[1], it.id, tostring(it.count), ItemName(it.id) or "kein Name"))
        end
    end
    if (d.srcItemID or 0) > 0 then
        Log(rec, string.format("  Start-Item %d -> %s", d.srcItemID, ItemName(d.srcItemID) or "kein Name"))
    end
end

function Probe.Quest(id)
    local QL = _G.C_QuestLog
    if not (QL and QL.GetQuestDetails and QL.RequestLoadQuestByID) then
        Say("C_QuestLog.GetQuestDetails gibt es in dieser ClassicAPI-Version nicht.")
        return
    end
    local st = Store()
    if not st then return end
    local rec = {}
    st[id] = rec
    local okC, cached = Call(QL.IsQuestDataCachedByID, id)
    rec[#rec + 1] = "vorher im Zwischenspeicher: " .. tostring(okC and cached)
    pcall(QL.RequestLoadQuestByID, id)
    Say("Quest " .. id .. ": Antwort in " .. WAIT .. " Sekunden ...")
    C_Timer.After(WAIT, function()
        local ok, d = pcall(QL.GetQuestDetails, id)
        if not (ok and type(d) == "table") then
            Log(rec, "Quest " .. id .. ": keine Antwort (unbekannt oder noch nicht geladen)" .. ((not ok) and (" - Fehler: " .. Short(d)) or ""))
            return
        end
        ReportDetails(id, rec, d)
        local okN, n = Call(QL.GetNumQuestObjectives, id)
        rec[#rec + 1] = "GetNumQuestObjectives: " .. tostring(okN and n or "-")
        RequestNames(d)
        C_Timer.After(WAIT, function() ReportNames(id, rec, d) end)
    end)
end

function Probe.Object(id)
    local CG = _G.C_GameObjectInfo
    if not (CG and CG.GetGameObjectInfoByID) then Say("C_GameObjectInfo gibt es nicht.") return end
    local st = Store()
    if not st then return end
    local rec = {}
    st["go" .. id] = rec
    rec[#rec + 1] = "vorher: " .. tostring(ObjectName(id))
    if CG.RequestLoadGameObjectByID then pcall(CG.RequestLoadGameObjectByID, id) end
    Say("Objekt " .. id .. ": Antwort in " .. WAIT .. " Sekunden ...")
    C_Timer.After(WAIT, function()
        Log(rec, "Objekt " .. id .. ": " .. tostring(ObjectName(id) or "keine Antwort"))
    end)
end

function Probe.Npc(id)
    local CC = _G.C_CreatureInfo
    if not (CC and CC.GetCreatureInfoByID) then Say("C_CreatureInfo gibt es nicht.") return end
    local st = Store()
    if not st then return end
    local rec = {}
    st["npc" .. id] = rec
    rec[#rec + 1] = "vorher: " .. tostring(CreatureName(id))
    if CC.RequestLoadCreatureByID then pcall(CC.RequestLoadCreatureByID, id) end
    Say("Kreatur " .. id .. ": Antwort in " .. WAIT .. " Sekunden ...")
    C_Timer.After(WAIT, function()
        Log(rec, "Kreatur " .. id .. ": " .. tostring(CreatureName(id) or "keine Antwort"))
    end)
end

function Probe.Command(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local go = msg:match("^go%s+(%d+)$")
    if go then Probe.Object(tonumber(go)) return end
    local npc = msg:match("^npc%s+(%d+)$")
    if npc then Probe.Npc(tonumber(npc)) return end
    local ids = {}
    for n in msg:gmatch("%d+") do ids[#ids + 1] = tonumber(n) end
    if #ids == 0 then ids = { 7, 6, 3904, 1467 } end
    for i, id in ipairs(ids) do
        if i > 8 then break end
        local qid = id
        C_Timer.After((i - 1) * (WAIT * 2 + 1), function() Probe.Quest(qid) end)
    end
    Say("Ergebnis steht auch in Codex.db.questProbe (SavedVariables nach /reload).")
end

_G.SLASH_FWQUESTPROBE1 = "/fwquest"
SlashCmdList["FWQUESTPROBE"] = function(msg) Probe.Command(msg) end
