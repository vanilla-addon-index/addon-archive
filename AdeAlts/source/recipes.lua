-- Ade Alts: recipes (index over the bundled recipe database + known / missing lists)
local AA = AdeAlts

local SPELLSRC = { A = "Learned automatically", Q = "Quest", T = "Trainer", W = "World object" }
local RECSRC = {
  C = "Chest", E = "Crafted by an engineer", D = "Drop", F = "Fishing",
  G = "Gift", P = "Pickpocketing", Q = "Quest", V = "Vendor",
}

-- craft record: { spellId, name, skill, spellSources, resultItem, minCharLevel, { {recipeItem, quality, sources}, ... } }
function AA.RIndex()
  if AA.ridx then return AA.ridx end
  local idx = { byName = {}, byItem = {}, byAny = {} }
  for prof, list in pairs(AA.RDATA) do
    local bn = {}
    idx.byName[prof] = bn
    for _, cr in ipairs(list) do
      local key = string.lower(cr[2])
      if not bn[key] then bn[key] = cr end
      if not idx.byAny[key] then idx.byAny[key] = {} end
      table.insert(idx.byAny[key], { prof = prof, c = cr })
      if cr[7] then
        for _, rc in ipairs(cr[7]) do
          if not idx.byItem[rc[1]] then idx.byItem[rc[1]] = {} end
          table.insert(idx.byItem[rc[1]], { prof = prof, c = cr })
        end
      end
    end
  end
  AA.ridx = idx
  return idx
end

-- "Trainer", "Vendor, Quest", ...
function AA.CraftSource(cr)
  local seen, out = {}, {}
  local function add(txt)
    if txt and not seen[txt] then
      seen[txt] = true
      table.insert(out, txt)
    end
  end
  for ch in string.gfind(cr[4] or "", ".") do add(SPELLSRC[ch]) end
  if cr[7] then
    for _, rc in ipairs(cr[7]) do
      for ch in string.gfind(rc[3] or "", ".") do add(RECSRC[ch]) end
    end
  end
  if table.getn(out) == 0 then return "Unknown" end
  return table.concat(out, ", ")
end

-- known / missing list of one profession of one character
-- mode: "known" | "missing"   sort: "level" | "name"
function AA.RecipeList(c, prof, mode, sort)
  local idx = AA.RIndex()
  local pr = c and c.prof and c.prof[prof]
  local rec = (pr and pr.rec) or {}
  local known = {}
  for _, n in ipairs(rec) do known[string.lower(n)] = true end
  local out = {}
  if mode == "missing" then
    local seen = {}
    for _, cr in ipairs(AA.RDATA[prof] or {}) do
      local key = string.lower(cr[2])
      if not known[key] and not seen[key] then
        seen[key] = true
        table.insert(out, { name = cr[2], skill = cr[3], cr = cr, prof = prof })
      end
    end
  else
    local bn = idx.byName[prof]
    for _, n in ipairs(rec) do
      local cr = bn and bn[string.lower(n)]
      table.insert(out, { name = n, skill = cr and cr[3] or 0, cr = cr, known = true, prof = prof })
    end
  end
  local function lv(e) if e.skill == 0 then return 9999 end return e.skill end
  if sort == "name" then
    table.sort(out, function(a, b) return a.name < b.name end)
  else
    table.sort(out, function(a, b)
      local la, lb = lv(a), lv(b)
      if la ~= lb then return la < lb end
      return a.name < b.name
    end)
  end
  return out
end

-- number of known recipes and (when the bundled database covers the profession) missing ones;
-- nil when the recipe list was never scanned. Professions without a database (e.g. Poisons) give known, nil.
function AA.RecipeCounts(c, prof)
  local pr = c and c.prof and c.prof[prof]
  if not pr or not pr.rec then return nil end
  if not AA.RDATA[prof] then return table.getn(pr.rec), nil end
  local miss = table.getn(AA.RecipeList(c, prof, "missing", "name"))
  return table.getn(pr.rec), miss
end

-- colour of a recipe level: known recipes by distance to the current skill, missing ones by learnability
function AA.RecipeColor(e, rank)
  if e.skill == 0 then return "|cff808080" end
  rank = rank or 0
  if e.known then
    local d = rank - e.skill
    if d < 15 then return "|cffff8040" elseif d < 30 then return "|cffffff00"
    elseif d < 45 then return "|cff40c040" end
    return "|cff808080"
  end
  if e.skill > rank then return "|cffff4040" end
  return "|cff40ff40"
end

-- the recipe tooltip (known / missing lists)
function AA.RecipeTip(row)
  local e = row.entry
  if not e then return end
  local c = AA.db.chars[AA.selKey or ""]
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  local cr = e.cr
  local shown = false
  if cr and cr[5] and cr[5] > 0 then
    shown = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. cr[5]) and GameTooltip:NumLines() > 0
  end
  if not shown then
    GameTooltip:ClearLines()
    GameTooltip:AddLine(e.name, 1, 1, 1)
  end
  GameTooltip:AddLine(" ")
  local pr = c and c.prof and c.prof[e.prof]
  local rank = pr and pr.r or 0
  if e.skill > 0 then
    if e.skill > rank then
      GameTooltip:AddLine("Requires " .. e.prof .. " (" .. e.skill .. ")  - skill " .. rank, 1, 0.3, 0.3)
    else
      GameTooltip:AddLine("Requires " .. e.prof .. " (" .. e.skill .. ")", 0.4, 1, 0.4)
    end
  end
  if cr and cr[6] and cr[6] > 0 then
    GameTooltip:AddLine("Requires character level " .. cr[6], 1, 1, 1)
  end
  if cr then
    GameTooltip:AddLine("Source: " .. AA.CraftSource(cr), 1, 0.82, 0)
    if cr[7] then
      for _, rc in ipairs(cr[7]) do
        local nm, link
        local ok, a, b = pcall(GetItemInfo, rc[1])
        if ok then nm, link = a, b end
        GameTooltip:AddLine("  " .. (link or nm or ("recipe item #" .. rc[1])), 1, 1, 1)
      end
    end
  end
  -- what the other alts with this profession know
  local lines = 0
  local key = string.lower(e.name)
  for _, k in ipairs(AA.SortedAlts and AA.SortedAlts() or {}) do
    local ch = AA.db.chars[k]
    local p2 = ch and ch.prof and ch.prof[e.prof]
    if p2 and p2.rec and lines < 12 then
      local has = false
      for _, n in ipairs(p2.rec) do if string.lower(n) == key then has = true; break end end
      if lines == 0 then GameTooltip:AddLine(" ") end
      lines = lines + 1
      local col = "|cff" .. AA.ClassHex(ch.class)
      if has then
        GameTooltip:AddLine(col .. ch.name .. "|r  |cff40ff40knows it|r")
      elseif e.skill > (p2.r or 0) then
        GameTooltip:AddLine(col .. ch.name .. "|r  |cffff6060needs " .. e.skill .. "  (has " .. (p2.r or 0) .. ")|r")
      else
        GameTooltip:AddLine(col .. ch.name .. "|r  |cffffd100can learn now|r")
      end
    end
  end
  GameTooltip:Show()
end
