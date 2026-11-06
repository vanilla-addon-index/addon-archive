RollForSoftRes = RollForSoftRes or {}
local sr = RollForSoftRes

if sr.SoftResDataTransformer then return end

local M = {}

-- Core's shared helpers. RollFor is guaranteed to be loaded: the TOC declares it as a
-- dependency, so the client refuses to load this addon without it.
local m = RollFor

local make_roller = m.Types.make_roller

-- What a provider's `decode` hands back. Named for the shape rather than for a website:
-- this file is the shared contract every provider decodes *into*, and both sites produce
-- the same document as far as anything below reads it. Fields neither one is required to
-- carry -- `quality`, and whatever a provider adds on top -- are optional here for the same
-- reason.
---@class SoftResDocument
---@field metadata SoftResDocumentMetadata
---@field hardreserves SoftResDocumentHardRessedItem[]
---@field softreserves SoftResDocumentEntry[]

---@class SoftResDocumentMetadata
---@field id string -- The id from the url.

---@class SoftResDocumentHardRessedItem
---@field id number
---@field quality ItemQuality?

---@class SoftResDocumentEntry
---@field name string -- Player name.
---@field items SoftResDocumentItem[]

-- Only `id` is read. A provider's document may carry more per item -- raidres puts a roll
-- bonus on every reservation -- and that is deliberately not modelled here: this addon has
-- no opinion about any of it, and whoever does reads the document for itself.
---@class SoftResDocumentItem
---@field id number
---@field quality ItemQuality?

---@class SoftRessedItem
---@field rollers Roller[]
---@field quality number

---@class HardRessedItem
---@field quality number

---@alias SoftResData table<ItemId, SoftRessedItem>
---@alias HardResData table<ItemId, HardRessedItem>

---@param data SoftResDocument
---@return SoftResData
---@return HardResData
function M.transform( data )
  local sr_result = {}
  local hr_result = {}
  local hard_reserves = data.hardreserves or {}
  local soft_reserves = data.softreserves or {}

  local function find_roller( roller_name, rollers )
    for _, roller in ipairs( rollers ) do
      if roller.name == roller_name then
        return roller
      end
    end
  end

  for _, soft_reserve in ipairs( soft_reserves or {} ) do
    local roller_name = soft_reserve.name
    local item_ids = soft_reserve.items or {}

    for _, item in ipairs( item_ids ) do
      local item_id = item.id

      if item_id then
        sr_result[ item_id ] = sr_result[ item_id ] or {
          quality = item.quality,
          rollers = {}
        }

        local roller = find_roller( roller_name, sr_result[ item_id ].rollers )

        if not roller then
          roller = make_roller( roller_name, 1 )
          table.insert( sr_result[ item_id ].rollers, roller )
        else
          -- A duplicate entry is how a list grants an extra roll. What else the entry
          -- carried is not this addon's business: whatever reads a site-specific field
          -- reads it off the imported document, which rides along on softres_imported.
          roller.rolls = roller.rolls + 1
        end
      end
    end
  end

  for _, item in ipairs( hard_reserves or {} ) do
    local item_id = item.id

    if item_id then
      hr_result[ item_id ] = {
        quality = item.quality
      }
    end
  end

  return sr_result, hr_result
end

sr.SoftResDataTransformer = M
return M
