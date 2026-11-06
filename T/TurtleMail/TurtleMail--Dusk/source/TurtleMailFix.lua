-- TurtleMailFix.lua
-- Compatibility/safety layer for TurtleMail 1.4.5 on Turtle WoW 1.18.x / Octo.
-- Loaded after TurtleMail.xml so it can replace fragile handlers before ADDON_LOADED/PLAYER_LOGIN.

if not TurtleMail then return end

local m = TurtleMail
local getn = table.getn
local function pack( ... ) return arg end

m.compat_version = "1.4.12"

local DEFAULT_SENT_FILTERS = {
  Money = 1,
  COD = 1,
  Other = 1,
}

local DEFAULT_RECEIVED_FILTERS = {
  Money = 1,
  COD = 1,
  Other = 1,
  Returned = 1,
  AH = 1,
  AHSold = 1,
  AHOutbid = 1,
  AHWon = 1,
  AHCancelled = 1,
  AHExpired = 1,
}

local INBOX_AUCTIONHOUSES = {
  [ "Stormwind Auction House" ] = true,
  [ "Alliance Auction House" ] = true,
  [ "Darnassus Auction House" ] = true,
  [ "Undercity Auction House" ] = true,
  [ "Thunder Bluff  Auction House" ] = true,
  [ "Horde Auction House" ] = true,
  [ "Blackwater Auction House" ] = true,
}

local function merge_defaults( target, defaults )
  for key, value in pairs( defaults ) do
    if target[ key ] == nil then
      target[ key ] = value
    end
  end
end

local function ensure_saved_variables()
  if type( m.api.TurtleMail_Log ) ~= "table" then
    m.api.TurtleMail_Log = {}
  end

  local log = m.api.TurtleMail_Log
  if type( log.Sent ) ~= "table" then log.Sent = {} end
  if type( log.Received ) ~= "table" then log.Received = {} end
  if type( log.Settings ) ~= "table" then log.Settings = {} end

  local settings = log.Settings
  if settings.Enabled == nil then settings.Enabled = false end

  if type( settings.SentFilters ) ~= "table" then settings.SentFilters = {} end
  if type( settings.ReceivedFilters ) ~= "table" then settings.ReceivedFilters = {} end
  merge_defaults( settings.SentFilters, DEFAULT_SENT_FILTERS )
  merge_defaults( settings.ReceivedFilters, DEFAULT_RECEIVED_FILTERS )

  if type( m.api.TurtleMail_AutoCompleteNames ) ~= "table" then
    m.api.TurtleMail_AutoCompleteNames = {}
  end
end

local function autocomplete_key()
  local realm = m.api.GetCVar and m.api.GetCVar( "realmName" ) or "UnknownRealm"
  local faction = m.api.UnitFactionGroup and m.api.UnitFactionGroup( "player" ) or "UnknownFaction"
  return tostring( realm or "UnknownRealm" ) .. "|" .. tostring( faction or "UnknownFaction" )
end

local function ensure_autocomplete_table()
  ensure_saved_variables()
  local key = autocomplete_key()
  if type( m.api.TurtleMail_AutoCompleteNames[ key ] ) ~= "table" then
    m.api.TurtleMail_AutoCompleteNames[ key ] = {}
  end
  return key, m.api.TurtleMail_AutoCompleteNames[ key ]
end

local function sanitize_autocomplete_table()
  local _, names = ensure_autocomplete_table()
  for name, last_seen in pairs( names ) do
    if type( name ) ~= "string" or type( last_seen ) ~= "number" then
      names[ name ] = nil
    end
  end
end

-- Turtle WoW/Octo can return a texture from CreateTexture without exposing it
-- through the expected global name. The original addon assumes the global exists.
local function ensure_horizontal_bars()
  local frame = m.api.SendMailFrame
  if not frame or not frame.CreateTexture then return false end

  if not m.api.MailHorizontalBarLeft then
    m.api.MailHorizontalBarLeft = frame:CreateTexture( nil, "BACKGROUND" )
  end
  if not m.api.MailHorizontalBarRight then
    m.api.MailHorizontalBarRight = frame:CreateTexture( nil, "BACKGROUND" )
  end

  return m.api.MailHorizontalBarLeft and m.api.MailHorizontalBarRight
end

-- Upstream keeps the real Send button and subject edit box in ad-hoc globals
-- (MailMailButton / MailSubjectEditBox), then replaces the Blizzard globals with
-- proxy tables. If another addon changes those globals, or sendmail_load() runs
-- with an already-proxied widget, the saved globals can become nil and later
-- calls crash. Preserve strong references before the upstream swap happens.
local preserved_send_mail_button = m.api.SendMailMailButton
local preserved_subject_edit_box = m.api.SendMailSubjectEditBox

local function is_named_widget( widget, expected_name )
  if not widget or type( widget.GetName ) ~= "function" then return false end
  return widget:GetName() == expected_name
end

local function ensure_send_mail_button()
  local button = preserved_send_mail_button

  if not is_named_widget( button, "SendMailMailButton" ) then
    button = m.real_send_mail_button
  end
  if not is_named_widget( button, "SendMailMailButton" ) then
    button = MailMailButton
  end
  if not is_named_widget( button, "SendMailMailButton" ) then
    button = m.api.SendMailMailButton
  end

  if is_named_widget( button, "SendMailMailButton" ) then
    preserved_send_mail_button = button
    m.real_send_mail_button = button
    MailMailButton = button
    return button
  end

  return nil
end

local function ensure_subject_edit_box()
  local edit_box = preserved_subject_edit_box

  if not is_named_widget( edit_box, "SendMailSubjectEditBox" ) then
    edit_box = m.real_subject_edit_box
  end
  if not is_named_widget( edit_box, "SendMailSubjectEditBox" ) then
    edit_box = MailSubjectEditBox
  end
  if not is_named_widget( edit_box, "SendMailSubjectEditBox" ) then
    edit_box = m.api.SendMailSubjectEditBox
  end

  if is_named_widget( edit_box, "SendMailSubjectEditBox" ) then
    preserved_subject_edit_box = edit_box
    m.real_subject_edit_box = edit_box
    MailSubjectEditBox = edit_box
    return edit_box
  end

  return nil
end

local function restore_real_mail_widgets_for_upstream()
  local button = ensure_send_mail_button()
  local edit_box = ensure_subject_edit_box()

  -- Only restore the Blizzard globals immediately before upstream sendmail_load().
  -- That function intentionally replaces them with proxy tables afterwards.
  if button then m.api.SendMailMailButton = button end
  if edit_box then m.api.SendMailSubjectEditBox = edit_box end
end

-- The upstream Open Mail button is created only once in inbox_load(). If that
-- creation is skipped/interrupted, or another UI addon hides/re-parents the
-- button afterwards, TurtleMail never recreates it. Keep the button recoverable,
-- but only mutate its layout when something is actually wrong. This avoids doing
-- repeated SetParent/ClearAllPoints/SetPoint work during inbox refresh bursts.
local function ensure_open_mail_button()
  local inbox = m.api.InboxFrame
  if not inbox or not m.api.CreateFrame then return nil end

  local button = m.api.TurtleMailOpenMailButton
  local created = false
  if not button or type( button.SetPoint ) ~= "function" then
    button = m.api.CreateFrame( "Button", "TurtleMailOpenMailButton", inbox, "UIPanelButtonTemplate" )
    m.api.TurtleMailOpenMailButton = button
    created = true
  end

  local parent_changed = false
  if button.GetParent and button.SetParent then
    if button:GetParent() ~= inbox then
      button:SetParent( inbox )
      parent_changed = true
    end
  elseif created and button.SetParent then
    button:SetParent( inbox )
    parent_changed = true
  end

  local needs_anchor = created or parent_changed
  if not needs_anchor and button.GetPoint then
    local point, relative_to, relative_point, x, y = button:GetPoint()
    needs_anchor = point ~= "BOTTOM"
      or (relative_to and relative_to ~= inbox)
      or relative_point ~= "BOTTOM"
      or x ~= -10
      or y ~= 90
  end

  if needs_anchor then
    if button.ClearAllPoints then button:ClearAllPoints() end
    button:SetPoint( "BOTTOM", inbox, "BOTTOM", -10, 90 )
  end

  local wanted_text = m.api.OPENMAIL or "Open Mail"
  local text_changed = created
  if button.GetText then
    text_changed = button:GetText() ~= wanted_text
  end
  if text_changed and button.SetText then
    button:SetText( wanted_text )
  end

  -- Recalculate dimensions only when the button was created or its label changed.
  if created or text_changed then
    local width = 120
    local font_string = button.GetFontString and button:GetFontString()
    if font_string and font_string.GetStringWidth then
      width = math.max( 120, 30 + (font_string:GetStringWidth() or 0) )
    end
    if button.SetWidth then button:SetWidth( width ) end
    if button.SetHeight then button:SetHeight( 25 ) end
  end

  if button.SetScript then
    local onclick = button.GetScript and button:GetScript( "OnClick" ) or nil
    if created or onclick ~= m.inbox_open_all then
      button:SetScript( "OnClick", m.inbox_open_all )
    end
  end

  if inbox.GetFrameLevel and button.SetFrameLevel then
    local target_level = (inbox:GetFrameLevel() or 0) + 5
    local current_level = button.GetFrameLevel and button:GetFrameLevel() or nil
    if current_level ~= target_level then
      button:SetFrameLevel( target_level )
    end
  end

  if button.Enable then
    if not button.IsEnabled or not button:IsEnabled() then
      button:Enable()
    end
  end
  if button.Show then
    if not button.IsShown or not button:IsShown() then
      button:Show()
    end
  end
  return button
end

-- Replace the fragile one-shot inbox loader with an idempotent version. This
-- preserves upstream behavior while making Open Mail recoverable instead of
-- relying on the initial CreateFrame call succeeding forever.
function m.inbox_load()
  if m.api.InboxFrame and m.api.InboxFrame.EnableMouse then
    m.api.InboxFrame:EnableMouse( false )
  end

  ensure_open_mail_button()

  for i = 1, 7 do
    local auction_texture = m.api[ "TurtleMailAuctionIcon" .. i .. "Texture" ]
    local returned_texture = m.api[ "TurtleMailReturnedArrow" .. i .. "Texture" ]
    local color = m.api.NORMAL_FONT_COLOR

    if color and auction_texture and auction_texture.SetVertexColor then
      auction_texture:SetVertexColor( color.r, color.g, color.b )
    end
    if color and returned_texture and returned_texture.SetVertexColor then
      returned_texture:SetVertexColor( color.r, color.g, color.b )
    end
  end
end

-- SavedVariables are not guaranteed to have a valid schema. Repair them before
-- the original handlers touch nested fields.
do
  local original = m.ADDON_LOADED
  function m.ADDON_LOADED()
    if arg1 == "TurtleMail" then
      ensure_saved_variables()
    end
    if original then original() end
    if arg1 == "TurtleMail" and m.info then
      m.info( "Compatibility fixes loaded (|cffeda55f" .. m.compat_version .. "|r)." )
    end
  end
end

do
  local original = m.PLAYER_LOGIN
  function m.PLAYER_LOGIN()
    ensure_saved_variables()
    sanitize_autocomplete_table()
    if original then original() end
  end
end

do
  local original = m.slash_command
  function m.slash_command( args )
    ensure_saved_variables()
    if original then return original( args ) end
  end
end

-- Make autocomplete resilient to missing/corrupt SavedVariables.
do
  local original = m.add_auto_complete_name
  function m.add_auto_complete_name( name )
    if type( name ) ~= "string" or name == "" then return end
    ensure_autocomplete_table()
    if original then return original( name ) end
  end
end

if GetSuggestions then
  local original = GetSuggestions
  function GetSuggestions()
    ensure_autocomplete_table()
    return original()
  end
end

-- Ensure the two horizontal bar textures exist before the original setup/update
-- routines try to address them by global name.
do
  local original = m.sendmail_load
  function m.sendmail_load()
    ensure_horizontal_bars()
    restore_real_mail_widgets_for_upstream()

    if original then
      local result = original()
      -- Upstream has now installed its proxy globals. Re-assert the private
      -- references used by the legacy MailMailButton/MailSubjectEditBox code.
      ensure_send_mail_button()
      ensure_subject_edit_box()
      return result
    end
  end
end

-- Replace the fragile upstream CanSend hook. The original directly calls the
-- global MailMailButton and crashes when that saved global is nil.
if m.hooks then
  m.hook.SendMailFrame_CanSend = function()
    local button = ensure_send_mail_button()
    if not button then return end

    local name_box = m.api.SendMailNameEditBox
    local send_money_button = m.api.SendMailSendMoneyButton
    local send_money_frame = m.api.SendMailMoney

    local recipient = name_box and name_box.GetText and name_box:GetText() or ""
    local attached = m.sendmail_num_attachments and m.sendmail_num_attachments() or 0
    local price = m.api.GetSendMailPrice and (tonumber( m.api.GetSendMailPrice() ) or 0) or 0
    local player_money = m.api.GetMoney and (tonumber( m.api.GetMoney() ) or 0) or 0
    local money = 0

    if send_money_button and send_money_button.GetChecked and send_money_button:GetChecked()
        and m.api.MoneyInputFrame_GetCopper and send_money_frame then
      money = tonumber( m.api.MoneyInputFrame_GetCopper( send_money_frame ) ) or 0
    end

    local can_send = not m.sendmail_sending
        and string.len( recipient ) > 0
        and money + price * math.max( 1, attached ) <= player_money

    if can_send then
      button:Enable()
    else
      button:Disable()
    end
  end
end

if m.hooks and m.hooks.SendMailFrame_Update then
  local original = m.hooks.SendMailFrame_Update
  m.hook.SendMailFrame_Update = function( ... )
    ensure_horizontal_bars()
    return original( unpack( arg ) )
  end
end

-- Ensure the legacy click handler sees a valid subject edit box and real send
-- button before it reads them. This protects the same upstream proxy hack from
-- producing a follow-up MailSubjectEditBox nil error.
do
  local original = m.send_mail_button_onclick
  function m.send_mail_button_onclick()
    ensure_send_mail_button()
    ensure_subject_edit_box()
    if original then return original() end
  end
end

-- Replace the upstream clear routine because it directly dereferences
-- MailMailButton and MailSubjectEditBox. Keep its behavior, but guard every UI
-- object so mailbox replacements cannot turn cleanup into another Lua error.
function m.sendmail_clear()
  local any_item

  for i = 1, 21 do
    local attachment = m.api[ "MailAttachment" .. i ]
    if attachment then
      any_item = any_item or attachment.item
      attachment.item = nil
    end
  end

  if any_item and m.api.ClearCursor and m.api.PickupContainerItem then
    m.api.ClearCursor()
    m.api.PickupContainerItem( unpack( any_item ) )
    m.api.ClearCursor()
  end

  local button = ensure_send_mail_button()
  if button and button.Disable then button:Disable() end

  local name_box = m.api.SendMailNameEditBox
  if name_box then
    if name_box.SetText then name_box:SetText( "" ) end
    if name_box.SetFocus then name_box:SetFocus() end
  end

  local subject = ensure_subject_edit_box()
  if subject and subject.SetText then subject:SetText( "" ) end

  if m.api.SendMailBodyEditBox and m.api.SendMailBodyEditBox.SetText then
    m.api.SendMailBodyEditBox:SetText( "" )
  end

  if m.api.MoneyInputFrame_ResetMoney and m.api.SendMailMoney then
    m.api.MoneyInputFrame_ResetMoney( m.api.SendMailMoney )
  end

  if m.api.SendMailRadioButton_OnClick then
    m.api.SendMailRadioButton_OnClick( 1 )
  end

  if m.api.SendMailFrame_Update then
    m.api.SendMailFrame_Update()
  end
end

-- Do not assume MailFrame exists during bag events.
function m.BAG_UPDATE()
  if m.api.MailFrame and m.api.MailFrame:IsVisible() and m.api.SendMailFrame_Update then
    m.api.SendMailFrame_Update()
  end
end

-- Safer MAIL_SHOW: package-button regions differ between UI replacements.
function m.MAIL_SHOW()
  -- Re-assert the legacy send-widget references whenever the mailbox opens.
  -- Open Mail follows the lighter Otari-style path: when the existing button
  -- is still shown and parented to InboxFrame, do nothing at all. Only invoke
  -- the full recovery routine if the button is missing, hidden, or re-parented.
  ensure_send_mail_button()
  ensure_subject_edit_box()

  local open_mail_button = m.api.TurtleMailOpenMailButton
  local open_mail_ok = open_mail_button
    and type( open_mail_button.SetPoint ) == "function"
    and (not open_mail_button.GetParent or open_mail_button:GetParent() == m.api.InboxFrame)
    and (not open_mail_button.IsShown or open_mail_button:IsShown())

  if not open_mail_ok then
    ensure_open_mail_button()
  end

  if not m.api.MailFrame then return end

  if m.api.TurtleMail_Point then
    m.debug( "Set point" )
    m.api.MailFrame:SetPoint( m.api.TurtleMail_Point.point, m.api.TurtleMail_Point.x, m.api.TurtleMail_Point.y )
  end

  if not m.first_show then
    m.first_show = true
    local package = m.api.SendMailPackageButton

    if package then
      if m.pfui_skin_enabled and m.api.pfUI and m.api.pfUI.api and m.api.pfUI.api.StripTextures then
        m.api.pfUI.api.StripTextures( package )
      end

      local regions = { package:GetRegions() }
      if regions[ 1 ] and regions[ 1 ].Hide then regions[ 1 ]:Hide() end
      if regions[ 3 ] and regions[ 3 ].Hide then regions[ 3 ]:Hide() end

      package:Disable()
      package:SetScript( "OnReceiveDrag", nil )
      package:SetScript( "OnDragStart", nil )
    end
  end

  if m.api.MailFrameTab3 then
    if m.log_enabled then
      m.api.MailFrameTab3:Show()
    else
      m.api.MailFrameTab3:Hide()
    end
  end

  m.timer = 0
  m.money_received = 0
  m.update_money( 0 )
end

-- Check bounds before querying inbox headers and tolerate nil COD values.
function m.on_update()
  if not m.api.MailFrame or not m.api.MailFrame:IsVisible() then return end

  if m._cursorItem then
    m.debug( "on_update: cursorItem" )
    m.cursorItem = m._cursorItem
    m._cursorItem = nil
  end

  if m.sendmail_update then
    m.debug( "on_update: sendmail" )
    m.sendmail_update = nil
    if m.sendmail_sending then
      m.debug( "m.sendmail_sending" )
      m.sendmail_send()
    end
  end

  if m.inbox_update then
    m.debug( "on_update: inbox_update" )
    m.inbox_update = false

    local index = tonumber( m.inbox_index ) or 1
    local total = m.api.GetInboxNumItems and (m.api.GetInboxNumItems() or 0) or 0

    if index > total then
      if (tonumber( m.money_received ) or 0) > 0 then
        m.info( string.format( "%s%s.", m.format_money( m.money_received ), L[ "collected" ] ) )
      end
      m.inbox_abort()
    else
      local _, _, _, _, _, cod, _, _, _, _, _, _, isGM = m.api.GetInboxHeaderInfo( index )
      cod = tonumber( cod ) or 0

      if m.inbox_skip or cod > 0 or isGM then
        m.inbox_skip = false
        m.inbox_index = index + 1
        m.inbox_update = true
      else
        m.inbox_open( index )
      end
    end
  end

  if type( m.timer ) ~= "number" then m.timer = 0 end
  if m.timer > 0 then
    m.timer = m.timer - 1
  elseif not m.inbox_opening and m.api.CheckInbox then
    m.timer = 200
    m.api.CheckInbox()
  end
end

-- init() bound the original on_update function before this compatibility file was
-- loaded. Rebind the frame script so the safer implementation above is actually used.
if m.update_frame and m.update_frame.SetScript then
  m.update_frame:SetScript( "OnUpdate", m.on_update )
end

-- Hide stale AH/returned icons on rows that no longer contain mail.
function m.MAIL_INBOX_UPDATE()
  if m.inbox_opening then
    m.inbox_update = true
  end

  if not m.api.InboxFrame then return end
  local page = tonumber( m.api.InboxFrame.pageNum ) or 1
  local total = m.api.GetInboxNumItems and (m.api.GetInboxNumItems() or 0) or 0

  for i = 1, 7 do
    local index = i + (page - 1) * 7
    local auction_icon = m.api[ "TurtleMailAuctionIcon" .. i ]
    local returned_icon = m.api[ "TurtleMailReturnedArrow" .. i ]

    if index <= total then
      local _, _, sender, _, _, _, _, _, _, was_returned = m.api.GetInboxHeaderInfo( index )
      if auction_icon then
        if INBOX_AUCTIONHOUSES[ sender ] then auction_icon:Show() else auction_icon:Hide() end
      end
      if returned_icon then
        if was_returned then returned_icon:Show() else returned_icon:Hide() end
      end
    else
      if auction_icon then auction_icon:Hide() end
      if returned_icon then returned_icon:Hide() end
    end
  end
end

-- Guard frame lookups used while the mailbox is opening/closing.
function m.inbox_update_lock()
  for i = 1, 7 do
    local icon = m.api[ "MailItem" .. i .. "ButtonIcon" ]
    local button = m.api[ "MailItem" .. i .. "Button" ]

    if icon and icon.SetDesaturated then
      icon:SetDesaturated( m.inbox_opening )
    end
    if m.inbox_opening and button and button.SetChecked then
      button:SetChecked( nil )
    end
  end
end

-- Locale-safe COD label.
function m.set_cod_text()
  local cod_amount = m.api.COD_AMOUNT or "COD:"
  local text = string.sub( cod_amount, 1, math.max( 0, string.len( cod_amount ) - 1 ) )

  if not m.pfui_skin_enabled then
    text = string.match( text, "^(.-)%s+%S+$" ) or text
  end

  if not m.api.SendMailMoneyText then return end
  if m.api.SendMailCODAllButton and m.api.SendMailCODAllButton:GetChecked() then
    m.api.SendMailMoneyText:SetText( text .. " " .. L[ "each mail" ] .. ":" )
  else
    m.api.SendMailMoneyText:SetText( text .. " " .. L[ "1st mail" ] .. ":" )
  end
end

function m.update_money( money )
  m.money_received = (tonumber( m.money_received ) or 0) + (tonumber( money ) or 0)
  if not m.api.MoneyReceived then return end

  m.api.MoneyReceived:SetText( L[ "Money received" ] .. ": " .. m.format_money( m.money_received ) )
  if m.money_received > 0 then
    m.api.MoneyReceived:Show()
  else
    m.api.MoneyReceived:Hide()
  end
end

-- The original hook reads arg[3]/arg[12] from the function INPUT arguments.
-- GetInboxHeaderInfo receives an inbox index; sender/canReply are RETURN values.
-- Capture the return list first so sender autocomplete actually works.
if m.hooks and m.hooks.GetInboxHeaderInfo then
  m.hook.GetInboxHeaderInfo = function( ... )
    if not m.orig.GetInboxHeaderInfo then return end
    local ret = pack( m.orig.GetInboxHeaderInfo( unpack( arg ) ) )
    local sender = ret[ 3 ]
    local canReply = ret[ 12 ]
    if sender and canReply then
      m.add_auto_complete_name( sender )
    end
    return unpack( ret )
  end
end

-- Guard MailFrame lookup in attachment bookkeeping.
do
  local original = m.sendmail_attached
  function m.sendmail_attached( bag, slot )
    if not m.api.MailFrame or not m.api.MailFrame:IsVisible() then return false end
    if original then return original( bag, slot ) end
    return false
  end
end

-- Fix sent-money logging and tolerate malformed/system mail subjects.
function m.log.add( log_type, state )
  if not m.log_enabled or type( state ) ~= "table" then return end
  ensure_saved_variables()
  m.debug( "Logging " .. tostring( log_type ) .. " message" )

  local data = {
    timestamp = time(),
    icon = state.icon,
    item = state.item,
  }

  local cod = tonumber( state.cod )
  if cod and cod > 0 then data.cod = cod end

  if log_type == "Sent" then
    data.participant = state.to or ""
    data.subject = state.sent_subject or state.subject or ""

    local sent_money = tonumber( state.sent_money ) or 0
    if not data.cod and sent_money > 0 then
      data.money = sent_money
    end
  else
    data.participant = state.from or ""
    data.subject = state.subject or ""
    data.returned = state.returned
    data.gm = state.gm

    local received_money = tonumber( state.money ) or 0
    if received_money > 0 then data.money = received_money end

    local function subject_matches( pattern )
      if type( pattern ) ~= "string" or pattern == "" or data.subject == "" then return false end
      local needle = string.gsub( pattern, "%%s", "" )
      return needle ~= "" and string.find( data.subject, needle, 1, true ) ~= nil
    end

    if subject_matches( m.api.AUCTION_SOLD_MAIL_SUBJECT ) then
      data.ah = "Sold"
    elseif subject_matches( m.api.AUCTION_REMOVED_MAIL_SUBJECT ) then
      data.ah = "Removed"
    elseif subject_matches( m.api.AUCTION_EXPIRED_MAIL_SUBJECT ) then
      data.ah = "Expired"
    elseif subject_matches( m.api.AUCTION_WON_MAIL_SUBJECT ) then
      data.ah = "Won"
    elseif subject_matches( m.api.AUCTION_OUTBID_MAIL_SUBJECT ) then
      data.ah = "Outbid"
    end
  end

  if type( m.api.TurtleMail_Log[ log_type ] ) ~= "table" then
    m.api.TurtleMail_Log[ log_type ] = {}
  end
  table.insert( m.api.TurtleMail_Log[ log_type ], data )
end

-- Calendar day buttons can retain an old .mails value or have no value at all.
-- Replace only the tooltip handler; calendar selection/layout remains upstream.
if m.calendar and m.calendar.show then
  local original_show = m.calendar.show

  local function calendar_on_enter( button )
    return function()
      local enabled = true
      if button.IsEnabled then enabled = button:IsEnabled() end
      local mails = tonumber( button.mails ) or 0

      if enabled and mails > 0 then
        m.api.GameTooltip:SetOwner( button, "ANCHOR_RIGHT" )
        m.api.GameTooltip:SetText( mails .. " mail" .. (mails > 1 and "s" or ""), 1, 1, 1, 1, true )
        m.api.GameTooltip:Show()
      else
        m.api.GameTooltip:Hide()
      end
    end
  end

  m.calendar.show = function( data, current_date, anchor, on_select )
    if type( data ) ~= "table" then data = {} end
    original_show( data, current_date or time(), anchor, on_select )

    for i = 1, 42 do
      local button = m.api[ "TurtleMailCalendarDay" .. i .. "Button" ]
      if button then
        button:SetScript( "OnEnter", calendar_on_enter( button ) )
      end
    end
  end
end

-- Validated targeted fixes: persistent autocomplete timestamps and clean send abort.
-- Kept in a local block so integrating the former test file does not alter scope.
do
  local m = TurtleMail
  local getn = table.getn
  local AUTOCOMPLETE_MAX_AGE = 60 * 60 * 24 * 30
  local EPOCH_THRESHOLD = 1000000000

  local function autocomplete_key()
    local realm = m.api.GetCVar and m.api.GetCVar( "realmName" ) or "UnknownRealm"
    local faction = m.api.UnitFactionGroup and m.api.UnitFactionGroup( "player" ) or "UnknownFaction"
    return tostring( realm or "UnknownRealm" ) .. "|" .. tostring( faction or "UnknownFaction" )
  end

  local function ensure_autocomplete_table()
    if type( m.api.TurtleMail_AutoCompleteNames ) ~= "table" then
      m.api.TurtleMail_AutoCompleteNames = {}
    end

    local key = autocomplete_key()
    if type( m.api.TurtleMail_AutoCompleteNames[ key ] ) ~= "table" then
      m.api.TurtleMail_AutoCompleteNames[ key ] = {}
    end

    return m.api.TurtleMail_AutoCompleteNames[ key ]
  end

  -- Older TurtleMail builds stored GetTime() values here. GetTime() is session uptime,
  -- so those values cannot be compared reliably across game/client restarts. Convert
  -- legacy uptime-style values to a safe current timestamp, then expire names using time().
  local function migrate_and_prune_autocomplete()
    local names = ensure_autocomplete_table()
    local now = time()

    for name, last_seen in pairs( names ) do
      if type( name ) ~= "string" or type( last_seen ) ~= "number" then
        names[ name ] = nil
      else
        if last_seen < EPOCH_THRESHOLD then
          last_seen = now
          names[ name ] = last_seen
        end

        if now - last_seen > AUTOCOMPLETE_MAX_AGE then
          names[ name ] = nil
        end
      end
    end
  end

  -- Store persistent timestamps for newly learned recipients.
  function m.add_auto_complete_name( name )
    if type( name ) ~= "string" or name == "" then return end
    local names = ensure_autocomplete_table()
    names[ name ] = time()
  end

  -- Keep the complete existing login flow, but migrate before the legacy cleanup
  -- runs and prune again afterwards using persistent timestamps.
  local original_player_login = m.PLAYER_LOGIN
  function m.PLAYER_LOGIN()
    migrate_and_prune_autocomplete()
    if original_player_login then original_player_login() end
    migrate_and_prune_autocomplete()
  end

  -- The send flow can remain stuck in sendmail_sending when an attachment
  -- disappears or cannot be attached between queueing and the actual SendMail call.
  -- Keep the upstream behavior, but explicitly abort the send state on that failure.
  function m.sendmail_send()
    if type( m.sendmail_state ) ~= "table" or type( m.sendmail_state.attachments ) ~= "table" then
      m.sendmail_sending = false
      m.sendmail_update = nil
      return
    end

    local item = table.remove( m.sendmail_state.attachments, 1 )
    if item then
      m.api.ClearCursor()
      m.orig.ClickSendMailItemButton()
      m.api.ClearCursor()
      m.orig.PickupContainerItem( unpack( item ) )
      m.orig.ClickSendMailItemButton()

      if not m.api.GetSendMailItem() then
        m.api.DEFAULT_CHAT_FRAME:AddMessage( "|cffabd473TurtleMail|r: " .. m.api.ERROR_CAPS, 1, 0, 0 )
        m.sendmail_sending = false
        m.sendmail_update = nil
        m.sendmail_state = nil
        m.api.ClearCursor()
        if m.api.SendMailFrame_Update then
          m.api.SendMailFrame_Update()
        end
        return
      end
    end

    local amount = m.sendmail_state.money
    m.sendmail_state.sent_money = m.sendmail_state.money
    m.sendmail_state.sent = false

    if amount > 0 then
      if not m.api.SendMailCODAllButton:GetChecked() then
        m.sendmail_state.money = 0
      end
      if m.sendmail_state.cod then
        m.sendmail_state.cod = amount
        m.api.SetSendMailCOD( amount )
      else
        m.sendmail_state.money = 0
        m.api.SetSendMailMoney( amount )
      end
    end

    local subject = m.sendmail_state.subject
    if subject == "" then
      if item then
        local item_name, texture, stack_count = m.api.GetSendMailItem()
        subject = item_name .. (stack_count > 1 and " (" .. stack_count .. ")" or "")
        m.sendmail_state.item = item_name
        m.sendmail_state.icon = texture
      else
        subject = "<" .. m.api.NO_ATTACHMENTS .. ">"
      end
    elseif m.sendmail_state.numMessages > 1 then
      subject = subject .. string.format( " [%d/%d]", m.sendmail_state.numMessages - getn( m.sendmail_state.attachments ),
        m.sendmail_state.numMessages )
    end

    m.sendmail_state.sent_subject = subject

    m.debug( "SendMail" )
    m.api.SendMail( m.sendmail_state.to, subject, m.sendmail_state.body )

    if getn( m.sendmail_state.attachments ) == 0 then
      m.sendmail_sending = false
    end
  end
end

-- Performance compatibility fix inspired by Otari98/TurtleMail: the upstream
-- GetContainerItemInfo hook builds a temporary table with pack()/unpack() on
-- every bag query. Bag and mailbox refreshes can call this hook very frequently,
-- creating avoidable garbage and occasional GC hitches. Detect the native return
-- count once after the normal PLAYER_LOGIN hook setup, then use a fixed-local
-- wrapper with no per-call temporary table. Exact return arity is preserved for
-- up to 12 values so extended/custom clients remain compatible; if detection is
-- inconclusive, the existing upstream hook is left untouched.
do
  local original_player_login = m.PLAYER_LOGIN
  local legacy_hook = m.hooks and m.hooks.GetContainerItemInfo or nil
  local detected_return_count

  local function count_returns( ... )
    return arg.n or getn( arg )
  end

  local function detect_container_info_return_count()
    local fn = m.orig and m.orig.GetContainerItemInfo
    if type( fn ) ~= "function" then return nil end

    -- Prefer an occupied inventory slot so clients that return no values for an
    -- empty slot cannot make us detect the wrong arity.
    if m.api.GetContainerNumSlots then
      for bag = 0, 4 do
        local slots = tonumber( m.api.GetContainerNumSlots( bag ) ) or 0
        for slot = 1, slots do
          local texture = fn( bag, slot )
          if texture then
            return count_returns( fn( bag, slot ) )
          end
        end
      end
    end

    -- A normal character should always have at least one item, but retain a
    -- conservative fallback for unusual test clients or empty inventories.
    local count = count_returns( fn( 0, 1 ) )
    if count and count > 0 then return count end
    return nil
  end

  local function optimized_get_container_item_info( bag, slot )
    local r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12 =
      m.orig.GetContainerItemInfo( bag, slot )

    if not r3 and m.sendmail_attached( bag, slot ) then
      r3 = 1
    end

    if detected_return_count == 1 then return r1 end
    if detected_return_count == 2 then return r1, r2 end
    if detected_return_count == 3 then return r1, r2, r3 end
    if detected_return_count == 4 then return r1, r2, r3, r4 end
    if detected_return_count == 5 then return r1, r2, r3, r4, r5 end
    if detected_return_count == 6 then return r1, r2, r3, r4, r5, r6 end
    if detected_return_count == 7 then return r1, r2, r3, r4, r5, r6, r7 end
    if detected_return_count == 8 then return r1, r2, r3, r4, r5, r6, r7, r8 end
    if detected_return_count == 9 then return r1, r2, r3, r4, r5, r6, r7, r8, r9 end
    if detected_return_count == 10 then return r1, r2, r3, r4, r5, r6, r7, r8, r9, r10 end
    if detected_return_count == 11 then return r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11 end
    if detected_return_count == 12 then return r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12 end

    -- Should not normally be reached; keep the previous behavior if a custom
    -- client exposes an unexpected signature.
    if legacy_hook then return legacy_hook( bag, slot ) end
    return r1, r2, r3, r4, r5
  end

  function m.PLAYER_LOGIN()
    if original_player_login then original_player_login() end

    detected_return_count = detect_container_info_return_count()
    if detected_return_count and detected_return_count >= 1 and detected_return_count <= 12 then
      m.api.GetContainerItemInfo = optimized_get_container_item_info
    end
  end
end

