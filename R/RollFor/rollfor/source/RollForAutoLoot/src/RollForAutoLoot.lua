RollForAutoLoot = RollForAutoLoot or {}
local al = RollForAutoLoot

-- Auto Loot, as a RollFor extension.
--
-- Master-loots the items the player has ticked -- and, under General, whole qualities -- the
-- moment a corpse opens, before anything else in the pipeline decides an item is still there.
-- The rule for what gets swept lives in src/AutoLoot.lua; this file is the integration surface.
--
-- It needs four things from core that a decorator-only extension does not: an award policy
-- (ctx.award_policy), a say in what gets announced as a drop (ctx.on_dropped_item), four
-- settings (ctx.config.register_toggle), and the selection tree (ctx.selection_tree), which
-- arrived with API version 5. The tree is drawn on the Loot tab of this addon's options page.
--
-- API 6 is the one that matters here: core performs the award now, so this addon decides and
-- stops. `RollForAutoLoot.claims` is gone with it -- ctx.loot_claim( slot ) answers the same
-- question about the slot that was actually taken, which is the question it was standing in
-- for. That is a deliberate break, and the one a third party could notice.
--
-- API 8 is ctx.open_options, which is how /rf autoloot brings the Loot tab up now that the list
-- is no longer a window of its own.
--
-- The registration below runs at file scope: the TOC declares `## Dependencies: RollFor`,
-- which makes the client load RollFor first and refuse to load this addon without it.

local M = {}

---@param ctx ExtensionContext
local function on_enable( ctx )
  -- Declared here rather than in on_ready because on_enable is the declaration phase and the
  -- options window reads these while building its rows. The cmd/display/help text is verbatim
  -- what core registered, so `/rf config auto-loot` and its three siblings are unchanged.
  ctx.config.register_toggle( "auto_loot",
    { cmd = "auto-loot", display = "Auto-loot", help = "toggle auto-loot" }, true )

  ctx.config.register_toggle( "auto_loot_announce",
    { cmd = "auto-loot-announce", display = "Announce auto-looted items",
      help = "toggle announcements of auto-loot items" }, true )

  -- Off, which is what it already was: core registered no default for this one, so it has been
  -- falsy for every player since it was added. Saying `false` out loud here changes nothing and
  -- is not the place to reconsider it.
  ctx.config.register_toggle( "auto_loot_messages",
    { cmd = "auto-loot-messages", display = "Auto-loot messages", help = "toggle auto-loot messages" }, false )

  -- An award policy rather than a loot handler that loots. Core walks the slots, runs the
  -- registered policies in whatever order the user has put them in, resolves the candidate
  -- index, sends the award and records who took the slot -- because GiveMasterLoot is
  -- asynchronous and only whoever sent one can say a slot is spoken for.
  --
  -- Which is also where "auto-loot beats round robin" went. It used to be written down in the
  -- rotation, as a call into this addon's `claims`; it is a list the user can reorder now, and
  -- neither addon names the other.
  --
  -- Guarded because the pass is built in on_ready and core calls this at loot time, so
  -- registering here is correct and arriving early is normal.
  ctx.award_policy( {
    name = "auto_loot",
    title = "Auto-loot",
    decide = function( slot, item )
      if not al.auto_loot then return end

      return al.auto_loot.decide( slot, item )
    end,
    on_awarded = function( slot, item, recipient )
      if al.auto_loot then al.auto_loot.on_awarded( slot, item, recipient ) end
    end
  } )

  -- Core cannot ask whether an item is going to be swept up, so the sweeper answers.
  --
  -- An item the player ticked by hand stays announced even when auto-loot announcements are
  -- off: ticking it is a deliberate choice about that item, and the announcement is how the
  -- raid learns it dropped at all. What is withheld is the incidental sweep -- a quality row,
  -- or anything under the loot threshold.
  --
  -- Guarded because the pass is built in on_ready and core reads this table at call time, so
  -- registering here is correct and arriving early is normal.
  ctx.on_dropped_item( function( item )
    if not al.auto_loot then return end

    if al.auto_loot.is_auto_looted( item )
        and not al.auto_loot.is_on_predefined_list( item )
        and not ctx.config.auto_loot_announce() then
      return false
    end
  end )
end

---@param ctx ExtensionContext
local function on_ready( ctx )
  local db = ctx.db( "db" )

  al.AutoLootDb.ensure_seeded( db )

  al.auto_loot = al.AutoLoot.new(
    ctx.api,
    db,
    ctx.config,
    ctx.player_info,
    ctx.chat
  )

  -- A subcommand of core's /rf. The list is on the Loot tab of this addon's options page, so
  -- that is what it opens. The tab is picked first, so the page draws it when the window
  -- shows it.
  ctx.on_rf_command( "autoloot", function()
    if al.options_page then al.options_page.select_tab( "Loot" ) end

    ctx.open_options()
  end )
end

function M.register()
  if not RollFor.Extensions then
    RollFor.warn( "Unsupported RollFor version.", "RollForAutoLoot" )
    return
  end

  return RollFor.Extensions.register( {
    name = "auto_loot",
    title = "Auto Loot",
    api_version = 8,
    default_enabled = true,

    -- This addon is the feature, and "Auto-loot" already says whether it does anything. A
    -- switch above that one asks the same question twice, and the two could disagree --
    -- Auto-loot ticked on a disabled extension reads as broken. Core draws no switch and
    -- keeps us on; the way to be rid of it entirely is the game's own AddOns list.
    hide_enabled_option = true,
    on_enable = on_enable,
    on_ready = on_ready,

    -- Core creates the canvas and asks us to fill it in. Declared here rather than from
    -- on_enable because a disabled extension still needs its page -- that page is where the
    -- switch to turn it back on lives, and on_enable does not run when we are off.
    --
    -- Kept, because /rf autoloot has to be able to tell it which tab to open on.
    options_page = function( ctx, parent )
      al.options_page = al.OptionsPage.new( ctx, parent )

      return al.options_page
    end
  } )
end

M.on_enable = on_enable
M.on_ready = on_ready

al.main = M

-- Registration happens on load, which is the whole point: by the time RollFor builds its
-- components on PLAYER_LOGIN, the registry already knows about us. Tests that want a clean
-- registry clear it and call M.register() again.
M.register()

return M
