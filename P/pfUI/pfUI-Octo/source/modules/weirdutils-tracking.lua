pfUI:RegisterModule("weirdutils-tracking", "vanilla", function ()
  -- pfUI Octo :: the game's tracking button, which WeirdUtils' minimap
  -- tracking menu lives on (29 Oct 2026; user: "minimap button should be
  -- movable just like any other or the option to add it into our drop down
  -- menu, resizable, border removal"). C.weirdutils:
  --   track        map (where the game puts it) | free (a mover: Move Frames)
  --                | bar (in the addon button panel) | hide
  --   track_size   px, 0 = the game's size (33)
  --   track_border "1" = the gold ring, "0" = a square icon in pfUI's frame
  local f = MiniMapTrackingFrame
  if not f then return end
  C.weirdutils = C.weirdutils or {}
  local S = C.weirdutils
  if S.track == nil then S.track = "map" end
  if S.track_size == nil then S.track_size = 0 end
  if S.track_border == nil then S.track_border = "1" end

  local TB = {}
  pfUI.trackbutton = TB
  local NAME = "MiniMapTrackingFrame"
  local home
  local function Remember()
    if home then return end
    local a, rel, rp, x, y = f:GetPoint()
    home = { parent = f:GetParent(), a = a, rel = rel, rp = rp, x = x, y = y }
  end

  local function Border()
    local ring, icon = MiniMapTrackingBorder, MiniMapTrackingIcon
    if S.track_border == "0" then
      if ring then ring:Hide() end
      if icon then
        icon:SetTexCoord(.08, .92, .08, .92)
        icon:ClearAllPoints()
        icon:SetAllPoints(f)
      end
      if not f.backdrop then CreateBackdrop(f, nil, true) end
      if f.backdrop then f.backdrop:Show() end
    else
      if ring then ring:Show() end
      if icon then
        icon:SetTexCoord(0, 1, 0, 1)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -5)
        icon:SetWidth(20)
        icon:SetHeight(20)
      end
      if f.backdrop then f.backdrop:Hide() end
    end
  end

  local function Size()
    local px = tonumber(S.track_size) or 0
    local base = S.track_border == "0" and 22 or 33
    f:SetWidth(base)
    f:SetHeight(base)
    if MiniMapTrackingBorder then
      MiniMapTrackingBorder:SetWidth(52)
      MiniMapTrackingBorder:SetHeight(52)
    end
    f:SetScale(px > 0 and px / base or 1)
  end

  function TB.Apply()
    Remember()
    local ab = pfUI.addonbuttons
    local inBar = ab and ab.GetPlace and ab:GetPlace(NAME) == "panel" and TB.wasBar
    if S.track == "bar" and ab and ab.SetPlace then
      Border()
      f:SetScale(1)
      if not TB.wasBar then TB.wasBar = true ab:SetPlace(NAME, "panel") end
      return
    elseif inBar or TB.wasBar then
      TB.wasBar = nil
      if ab and ab.SetPlace then ab:SetPlace(NAME, "map") end
    end
    Border()
    Size()
    f:SetAlpha(1)
    if S.track == "hide" then
      f:SetAlpha(0)
      f:EnableMouse(false)
      return
    end
    f:EnableMouse(true)
    if S.track == "free" then
      f:SetParent(UIParent)
      f:SetFrameStrata("MEDIUM")
      if not TB.free then
        TB.free = true
        if not (C.position and C.position[NAME]) then
          f:ClearAllPoints()
          f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        end
        UpdateMovable(f)
      end
      -- (1.12: a frame moved out of a hidden parent stays unseen until shown again)
      if f:IsShown() then f:Hide() f:Show() end
    else
      if TB.free then
        TB.free = nil
        RemoveMovable(f)
        if C.position then C.position[NAME] = nil end
      end
      f:SetParent(home.parent)
      f:ClearAllPoints()
      f:SetPoint(home.a or "TOPLEFT", home.rel or home.parent, home.rp or "TOPLEFT", home.x or 0, home.y or 0)
    end
  end

  -- put in the panel by us last session: it is in the panel's own "add" list
  local add = pfUI_cache and pfUI_cache.abuttons and pfUI_cache.abuttons.add
  for _, n in ipairs(add or {}) do if n == NAME then TB.wasBar = true end end
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:SetScript("OnEvent", function()
    this:UnregisterAllEvents()
    TB.Apply()
  end)
end)
