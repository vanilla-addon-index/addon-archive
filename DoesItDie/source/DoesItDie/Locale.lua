-- English-only helpers shared by the tracking core and options.
local ns = DoesItDieVanilla
if not ns.ready then return end
local L = {}
ns.locale = L
function L.T(text) return text end
function L.addNames() end
function L.addClientNames() return {} end
-- English spell parsing is implemented in DoesItDie.lua.
function L.parseDot() return nil end
function L.isFinisher() return false end
function L.comboPointsAwarded() return nil end
local logged = {}
function L.shouldLogUnread(id, description)
    if type(description) ~= "string" or description == "" or logged[id] then return false end
    logged[id] = true
    return true
end
