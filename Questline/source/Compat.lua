-- Session-only display hooks. Never write pfQuest's configuration or database.
local Q=Questline
local function suppress(frame,predicate)
  if not frame or frame.questlineShow then return end
  frame.questlineShow=frame.Show
  frame.Show=function(widget)
    if predicate() then widget:Hide() else widget.questlineShow(widget) end
  end
end
local function hideLegacyPins() return QuestlineSettings and not QuestlineSettings.legacy end
local function hideLegacyTracker() return QuestlineSettings and QuestlineSettings.tracker end
function Q:ApplyCompatibility()
  -- Native turn-in dots share an atlas with resource and party blips.
  -- Replace it once, without fighting other addons that set their own atlas.
  if not self.minimapBlipsApplied and Minimap and Minimap.SetBlipTexture then
    Minimap:SetBlipTexture("Interface\\AddOns\\Questline\\Textures\\minimap-blips")
    self.minimapBlipsApplied=true
  end
  if pfMap then
    if not self.oldBuildNode and pfMap.BuildNode then
      self.oldBuildNode=pfMap.BuildNode
      pfMap.BuildNode=function(map,name,parent)
        local frame=Q.oldBuildNode(map,name,parent)
        if parent==WorldMapButton then suppress(frame,hideLegacyPins) end
        return frame
      end
    end
    for _,pin in ipairs(pfMap.pins or {}) do
      suppress(pin,hideLegacyPins)
      if hideLegacyPins() then pin:Hide() end
    end
    if pfMap.UpdateNodes then pfMap:UpdateNodes() end
  end
  if WorldMapButton and WorldMapButton.routes then
    suppress(WorldMapButton.routes,hideLegacyPins)
    if hideLegacyPins() then WorldMapButton.routes:Hide() else WorldMapButton.routes:Show() end
  end
  for _,frame in ipairs({QuestWatchFrame,pfQuestMapTracker}) do
    suppress(frame,hideLegacyTracker)
    if hideLegacyTracker() or (frame==pfQuestMapTracker and pfQuest_config and pfQuest_config.showtracker=="0") then frame:Hide()
    elseif frame then frame:Show() end
  end
  if not hideLegacyTracker() and QuestWatch_Update then QuestWatch_Update() end
end
