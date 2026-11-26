--[[----------------------------------------------------------------------
OctoPad Adapters  -  everything OctoPad knows about specific windows, in one place

One entry per window (by its frame name).  Every field is optional:

  only      = { ... }   while this window is open, the D-pad only reaches these widgets.
                        A plain string is an exact frame name, a string starting with "^" is a Lua pattern.
  preferred = function(H)  the most likely widget right now (or nil); runs before `buttons`
  buttons   = { ... }   most likely buttons, in order; the first usable one gets the focus
  advance   = { { pattern, targets }, ... }
                        after clicking a widget whose name matches `pattern`, the focus moves to the first
                        usable button in `targets` (nil targets = this window's usual most-likely widget).
                        Nothing usable (a skill you can't learn yet): the focus stays put.

ORDER decides which window wins when several are open.

H = helpers from OctoPadUI.lua: H.ClickableByName(name), H.IsClickable(w), H.Shown(name), H.ListButton(prefix,
count, scoreFn), H.QuestChoiceNeeded().  Lua 5.0.

Adding a window = adding one entry here.
------------------------------------------------------------------------]]

local OP = OctoPad

local DIFF_RANK = { optimal = 4, medium = 3, easy = 2, trivial = 1, available = 2 }

local A = {}

A.QuestFrame = {
  only = { "QuestFrameAcceptButton", "QuestFrameDeclineButton", "QuestFrameCompleteQuestButton",
           "QuestFrameCompleteButton", "QuestFrameGoodbyeButton", "QuestFrameCancelButton",
           "^QuestRewardItem", "^QuestTitleButton", "^QuestProgressItem" },
  preferred = function(H) return H.QuestChoiceNeeded() end,       -- several rewards, none picked: a reward first
  buttons = { "QuestFrameAcceptButton", "QuestFrameCompleteQuestButton", "QuestFrameCompleteButton",
              "QuestTitleButton1", "QuestFrameGoodbyeButton" },
  advance = {
    { "^QuestRewardItem", { "QuestFrameCompleteQuestButton" } },
    { "^QuestTitleButton%d", nil },
  },
}

A.GossipFrame = {
  buttons = { "GossipTitleButton1", "GossipFrameGreetingGoodbyeButton" },
  advance = { { "^GossipTitleButton%d", nil } },
}

A.TradeFrame = { buttons = { "TradeFrameTradeButton" } }

-- trainer: the first skill you can learn, or Train once a learnable one is selected
A.ClassTrainerFrame = {
  preferred = function(H)
    if not GetTrainerServiceInfo then return nil end
    local sel = GetTrainerSelectionIndex and GetTrainerSelectionIndex()
    if sel and sel > 0 then
      local _, _, cat = GetTrainerServiceInfo(sel)
      if cat == "available" then
        local b = H.ClickableByName("ClassTrainerTrainButton")
        if b then return b end
      end
    end
    return H.ListButton("ClassTrainerSkill", 20, function(id)
      local _, _, cat = GetTrainerServiceInfo(id)
      if cat == "available" then return 1 end
      return nil
    end)
  end,
  buttons = { "ClassTrainerTrainButton" },
  advance = { { "^ClassTrainerSkill%d", { "ClassTrainerTrainButton" } } },
}

A.PetitionFrame = { buttons = { "PetitionFrameSignButton", "PetitionFrameRequestButton" } }
A.TabardFrame = { buttons = { "TabardFrameAcceptButton" } }
A.LootFrame = { buttons = { "LootButton1" } }

-- enchanting / pet training: a recipe that still gives skill-ups, or Create once a usable one is selected
A.CraftFrame = {
  preferred = function(H)
    if not GetCraftInfo then return nil end
    local sel = GetCraftSelectionIndex and GetCraftSelectionIndex()
    if sel and sel > 0 then
      local _, _, ty, avail = GetCraftInfo(sel)
      if ty ~= "header" and ((avail or 0) > 0 or ty == "available") then
        local b = H.ClickableByName("CraftCreateButton")
        if b then return b end
      end
    end
    return H.ListButton("Craft", 25, function(id)
      local _, _, ty, avail = GetCraftInfo(id)
      if ty == "header" or ty == "used" then return nil end
      if (avail or 0) < 1 and ty ~= "available" then return nil end
      return DIFF_RANK[ty] or 1
    end)
  end,
  buttons = { "CraftCreateButton" },
  advance = { { "^Craft%d", { "CraftCreateButton" } } },
}

-- professions: craftable recipe with the best skill-up colour (orange > yellow > green > grey)
A.TradeSkillFrame = {
  preferred = function(H)
    if not GetTradeSkillInfo then return nil end
    local sel = GetTradeSkillSelectionIndex and GetTradeSkillSelectionIndex()
    if sel and sel > 0 then
      local _, ty, avail = GetTradeSkillInfo(sel)
      if ty ~= "header" and (avail or 0) > 0 then
        local b = H.ClickableByName("TradeSkillCreateButton")
        if b then return b end
      end
    end
    return H.ListButton("TradeSkillSkill", 25, function(id)
      local _, ty, avail = GetTradeSkillInfo(id)
      if ty == "header" or (avail or 0) < 1 then return nil end
      return DIFF_RANK[ty] or 1
    end)
  end,
  buttons = { "TradeSkillCreateButton" },
  advance = { { "^TradeSkillSkill%d", { "TradeSkillCreateButton" } } },
}

A.ItemTextFrame = { buttons = { "ItemTextNextPageButton" } }

A.AuctionFrame = {
  advance = {
    { "^BrowseButton%d",   { "BrowseBuyoutButton", "BrowseBidButton" } },
    { "^BidButton%d",      { "BidBuyoutButton", "BidBidButton" } },
    { "^AuctionsButton%d", { "AuctionsCancelAuctionButton" } },
  },
}

A.MailFrame = {
  advance = { { "^MailItem%dButton", { "OpenMailPackageButton", "OpenMailMoneyButton", "OpenMailReplyButton" } } },
}

OP.Adapters = A
OP.ADAPTER_ORDER = { "QuestFrame", "GossipFrame", "TradeFrame", "ClassTrainerFrame", "PetitionFrame",
                     "TabardFrame", "LootFrame", "CraftFrame", "TradeSkillFrame", "ItemTextFrame" }

-- name matches an entry of an `only` / pattern list
function OP.AdapterMatch(list, nm)
  if not nm or not list then return false end
  local i
  for i = 1, table.getn(list) do
    local e = list[i]
    if string.sub(e, 1, 1) == "^" then
      if string.find(nm, e) then return true end
    elseif e == nm then
      return true
    end
  end
  return false
end

-- the advance rule for a clicked widget name (searches every adapter)
function OP.AdapterAdvance(nm)
  if not nm then return nil end
  local k, ad
  for k, ad in pairs(A) do
    if ad.advance then
      local i
      for i = 1, table.getn(ad.advance) do
        if string.find(nm, ad.advance[i][1]) then return ad.advance[i] end
      end
    end
  end
  return nil
end
