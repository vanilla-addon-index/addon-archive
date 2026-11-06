RollForSoftRes = RollForSoftRes or {}
local sr = RollForSoftRes

if sr.SoftResGui then return end

-- Core's shared helpers. RollFor is guaranteed to be loaded: the TOC declares it as a
-- dependency, so the client refuses to load this addon without it.
local m = RollFor

local M                = {}

--local softres_data     = "eNqllE1r4zAQhv/LnH1wXMuOfWt7WhaaQndPJYfBmsQishRG0i5syH9fmVBQoZVbfJwPzzyaeT0XmMijRI/QX0BJ6MGLcBA1FKCM82gGir4TMkbPqKQkA/0BtaMCBib0JO899Jumq6u6KzdVAeEs37lFVZdNAYxKvnhk7+aICVoXoO1wumXebKncYFn+Zh2bxobG+rk9XAtw9uCZHPEfctC/XoCt1g/WhGiVBZx1cDtDN8PgNH+2G0dUE/IpVho0uhiEv8isLCe140M9Tbea8wCqbVt3aTgCEce61+Itoak2HyRsrvs5ZZnrB1tzCJxQSQ6xcoapa8U2y9S1zSqmFzJuDAnSmRU5n52TKNv8nNq2XMP0k4NEfr+8WTFZqKa9y0N9TP1lqMdRHY8J0xiMpwU9iaU51at296zJn/E7cvpkMylS06yaEtt/qBOkCY+0IPBmQeCiW0P0K7h0RG7ECU1eSWX2DNyV9XaVvJ8GCj7941CjVHkmUW0XTlMrPmHax/uNLJMbur/+B/fD0T0="

---@diagnostic disable-next-line: undefined-global
local UIParent         = UIParent
---@diagnostic disable-next-line: undefined-global
local ChatFontNormal   = ChatFontNormal

local frame_backdrop   = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true,
  tileSize = 32,
  edgeSize = 32,
  insets = { left = 8, right = 8, top = 8, bottom = 8 }
}

local control_backdrop = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

---@param gui_elements table -- core's widget set; the dropdown is one of its rows
---@param on_provider_change fun( id: string )
---@param is_inert fun(): boolean -- simulating, or no provider registered: either way, do not take focus
local function create_frame( api, gui_elements, on_import, on_clear, on_cancel, on_dirty, is_inert, on_provider_change )
  local frame = m.create_backdrop_frame( api(), "Frame", "RollForSoftResImportFrame", UIParent )
  frame:Hide()
  frame:SetWidth( 565 )
  frame:SetHeight( 300 )
  frame:SetPoint( "CENTER", UIParent, "CENTER", 0, 0 )
  frame:EnableMouse()
  frame:SetMovable( true )
  frame:SetResizable( true )
  frame:SetFrameStrata( "DIALOG" )

  frame:SetBackdrop( frame_backdrop )
  frame:SetBackdropColor( 0, 0, 0, 1 )

  if frame.SetMinResize then
    frame:SetMinResize( 400, 200 )
  elseif frame.SetResizeBounds then
    frame:SetResizeBounds( 400, 200 )
  end
  frame:SetToplevel( true )

  local backdrop = m.create_backdrop_frame( api(), "Frame", nil, frame )
  backdrop:SetBackdrop( control_backdrop )
  backdrop:SetBackdropColor( 0, 0, 0 )
  backdrop:SetBackdropBorderColor( 0.4, 0.4, 0.4 )

  backdrop:SetPoint( "TOPLEFT", frame, "TOPLEFT", 17, -18 )
  backdrop:SetPoint( "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -17, 51 )

  local scroll_frame = api().CreateFrame( "ScrollFrame", "a@ScrollFrame@c", backdrop, "UIPanelScrollFrameTemplate" )
  scroll_frame:SetPoint( "TOPLEFT", 5, -6 )
  scroll_frame:SetPoint( "BOTTOMRIGHT", -28, 6 )
  scroll_frame:EnableMouse( true )

  local scroll_child = api().CreateFrame( "Frame", nil, scroll_frame )
  scroll_frame:SetScrollChild( scroll_child )
  scroll_child:SetHeight( 2 )
  scroll_child:SetWidth( 2 )

  local editbox = api().CreateFrame( "EditBox", nil, scroll_child )
  editbox:SetPoint( "TOPLEFT", 0, 0 )
  editbox:SetHeight( 50 )
  editbox:SetWidth( 50 )
  editbox:SetMultiLine( true )
  editbox:SetTextInsets( 5, 5, 3, 3 )
  editbox:EnableMouse( true )
  editbox:SetAutoFocus( false )
  editbox:SetFontObject( ChatFontNormal )
  frame.editbox = editbox

  editbox:SetScript( "OnEscapePressed", function() editbox:ClearFocus() end )
  scroll_frame:SetScript( "OnMouseUp", function()
    if not is_inert() then editbox:SetFocus() end
  end )

  local function fix_size()
    scroll_child:SetHeight( scroll_frame:GetHeight() )
    scroll_child:SetWidth( scroll_frame:GetWidth() )
    editbox:SetWidth( scroll_frame:GetWidth() )
  end

  scroll_frame:SetScript( "OnShow", fix_size )
  scroll_frame:SetScript( "OnSizeChanged", fix_size )

  local cancel_button = api().CreateFrame( "Button", nil, frame, "UIPanelButtonTemplate" )
  frame.cancel_button = cancel_button

  cancel_button:SetScript( "OnClick", function()
    frame:Hide()
    editbox:SetText( on_cancel() or "" )
  end )

  cancel_button:SetPoint( "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 21 )
  cancel_button:SetHeight( 20 )
  cancel_button:SetWidth( 68 )
  cancel_button:SetText( "Close" )

  local clear_button = api().CreateFrame( "Button", nil, frame, "UIPanelButtonTemplate" )
  frame.clear_button = clear_button

  clear_button:SetScript( "OnClick",
    function()
      editbox:SetText( "" )
      cancel_button:SetText( "Close" )
      on_clear()
    end )

  clear_button:SetPoint( "RIGHT", cancel_button, "LEFT", -10, 0 )
  clear_button:SetHeight( 20 )
  clear_button:SetWidth( 68 )
  clear_button:SetText( "Clear" )

  local import_button = api().CreateFrame( "Button", nil, frame, "UIPanelButtonTemplate" )
  frame.import_button = import_button

  import_button:SetScript( "OnClick", function()
    on_import( function()
      frame:Hide()
    end )
  end )

  import_button:SetPoint( "RIGHT", clear_button, "LEFT", -10, 0 )
  import_button:SetHeight( 20 )
  import_button:SetWidth( 82 )
  import_button:SetText( "Import!" )

  -- Which site the pasted string came from, in the button row and immediately left of the
  -- button it governs. Always here, even with a single provider installed: a control that
  -- appears and disappears is a layout that changes shape underneath the user.
  local provider_dropdown = gui_elements.dropdown( frame )
  provider_dropdown:SetPoint( "RIGHT", import_button, "LEFT", -10, -2.5 )
  provider_dropdown:SetText( "SR data provider" )
  provider_dropdown:SetDropdownWidth( 89 )
  -- The widget lifts its label 3px so it centres against the box's artwork. This row wants
  -- a different balance: the label a shade above the box, and the selected value a pixel
  -- above where the box's own artwork would put it.
  provider_dropdown:SetLabelLift( 1.5 )
  provider_dropdown:SetValueLift( 1 )
  provider_dropdown.on_change = on_provider_change
  frame.provider_dropdown = provider_dropdown

  -- Shown instead of the dropdown when nothing has registered a decoder, over the paste
  -- area rather than in the button row -- there is no room for a sentence down there, and
  -- this is the same treatment the simulation lock above uses for the same kind of state:
  -- "you cannot import right now, and here is why". The window still opens and the saved
  -- string is still in it, because it is still the user's.
  local provider_message = frame:CreateFontString( nil, "OVERLAY", "GameFontNormal" )
  provider_message:SetPoint( "CENTER", backdrop, "CENTER", 0, 0 )
  provider_message:SetWidth( 320 )
  provider_message:SetJustifyH( "CENTER" )
  provider_message:SetTextColor( 1, 0.184, 0.184, 1 )
  provider_message:SetText( "No SoftRes data providers registered." )
  provider_message:Hide()
  frame.provider_message = provider_message

  editbox:SetScript( "OnTextChanged", function( _ )
    scroll_frame:UpdateScrollChildRect()
    on_dirty( import_button, clear_button, cancel_button )
  end )

  frame:SetScript( "OnShow", function()
    cancel_button:SetText( "Close" )
    on_dirty( import_button, clear_button, cancel_button )
  end )

  do
    local cursor_offset, cursor_height
    local idle_time

    local function fix_scroll( _, elapsed )
      if cursor_offset and cursor_height then
        idle_time = 0
        local height = scroll_frame:GetHeight()
        local range = scroll_frame:GetVerticalScrollRange()
        local scroll = scroll_frame:GetVerticalScroll()
        cursor_offset = -cursor_offset

        while cursor_offset < scroll do
          scroll = scroll - (height / 2)
          if scroll < 0 then scroll = 0 end
          scroll_frame:SetVerticalScroll( scroll )
        end

        while cursor_offset + cursor_height > scroll + height and scroll < range do
          scroll = scroll + (height / 2)
          if scroll > range then scroll = range end
          scroll_frame:SetVerticalScroll( scroll )
        end
      elseif not idle_time or idle_time > 2 then
        frame:SetScript( "OnUpdate", nil )
        idle_time = nil
      else
        idle_time = idle_time + elapsed
      end

      cursor_offset = nil
    end

    editbox:SetScript( "OnCursorChanged", function( _, _, y, _, h )
      cursor_offset, cursor_height = y, h
      if not idle_time then
        frame:SetScript( "OnUpdate", fix_scroll )
      end
    end )
  end

  local sim_overlay = api().CreateFrame( "Frame", nil, backdrop )
  sim_overlay:SetAllPoints( backdrop )
  sim_overlay:SetFrameLevel( scroll_frame:GetFrameLevel() + 10 )
  sim_overlay:EnableMouse( true )
  sim_overlay:Hide()
  frame.sim_overlay = sim_overlay

  local sim_label = sim_overlay:CreateFontString( nil, "OVERLAY", "GameFontNormal" )
  sim_label:SetPoint( "CENTER", sim_overlay, "CENTER", 0, 0 )
  sim_label:SetWidth( 320 )
  sim_label:SetJustifyH( "CENTER" )
  sim_label:SetTextColor( 1, 0.184, 0.184, 1 )
  sim_label:SetText( "Testing in progress.\n\nSoft-res data cannot be imported until you reload the UI." )

  -- Just the addon's name. What this window is for is the dropdown's business now, and it
  -- says so in words -- "SR data provider" -- rather than leaving a bare "SR" down here to
  -- carry it.
  local label = frame:CreateFontString( nil, "OVERLAY", "GameFontNormal" )
  label:SetPoint( "BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 25 )
  label:SetTextColor( 1, 1, 1, 1 )
  label:SetText( m.colors.blue( "RollFor" ) )

  ---@diagnostic disable-next-line: undefined-global
  table.insert( UISpecialFrames, "RollForSoftResImportFrame" )
  return frame
end

---@param is_simulating fun(): boolean
---@param provider_db table -- ctx.db( "provider" ); remembers the dropdown's selection
---@param gui_elements table -- core's widget set
function M.new( api, import_encoded_softres_data, softres_check, softres, clear_data, reset_loot_announcements,
                is_simulating, provider_db, gui_elements )
  local softres_data
  local edit_box_text
  local dirty = false
  local frame

  local function locked()
    return is_simulating and is_simulating() and true or false
  end

  -- The dropdown's selection, remembered across sessions. This is not the same fact as the
  -- provider recorded with the imported list: switching the dropdown re-decodes nothing,
  -- so what is on disk keeps whichever decoder produced it until the next Import.
  --
  -- A saved choice whose addon is no longer installed falls back to the first registered
  -- provider without overwriting what is saved, so reinstalling it restores the choice.
  ---@return string?
  local function selected_provider()
    local providers = sr.providers()

    for _, provider in ipairs( providers ) do
      if provider.id == provider_db.selected then return provider.id end
    end

    return providers[ 1 ] and providers[ 1 ].id or nil
  end

  local function has_providers()
    return sr.providers()[ 1 ] ~= nil
  end

  -- Both reasons the editbox refuses input, in one answer, for the click handler that only
  -- cares whether it may take focus.
  local function inert()
    return locked() or not has_providers()
  end

  local function on_provider_change( id )
    provider_db.selected = id
  end

  -- Repopulates the row from the registry. Providers register in on_enable, which is over
  -- long before this window is ever built, so this runs once per open rather than watching
  -- for changes -- enabling or disabling an extension asks for a UI reload anyway.
  local function apply_providers()
    if not frame then return end

    local providers = sr.providers()
    local options = {}

    for _, provider in ipairs( providers ) do
      table.insert( options, { value = provider.id, label = provider.title } )
    end

    frame.provider_dropdown:SetOptions( options )
    frame.provider_dropdown:SetValue( selected_provider() )

    if has_providers() then
      frame.provider_dropdown:Show()
      frame.provider_message:Hide()
    else
      frame.provider_dropdown:Hide()
      frame.provider_message:Show()
    end
  end

  -- RollSimulator wipes the soft-res data to fake its own and never restores it, so an
  -- import landing mid-simulation would mix real rollers into the fake raid. The window
  -- stays inert until the reload that ends the simulation.
  local function apply_lock()
    if not frame then return end

    local editbox = frame.editbox

    if locked() then
      editbox:ClearFocus()
      editbox:SetText( "" )
      editbox:EnableMouse( false )
      if editbox.EnableKeyboard then editbox:EnableKeyboard( false ) end
      frame.sim_overlay:Show()
      return
    end

    frame.sim_overlay:Hide()

    -- With no decoder registered there is nothing a paste could become, so the editbox goes
    -- inert -- but the text stays. The simulation lock above clears it; this one must not.
    -- The string in there is the user's, and a missing provider addon is a state of the
    -- install, not a reason to throw data away.
    local usable = has_providers()

    if not usable then editbox:ClearFocus() end
    editbox:EnableMouse( usable )
    if editbox.EnableKeyboard then editbox:EnableKeyboard( usable ) end
  end

  local function on_import( close_window_fn )
    local provider_id = selected_provider()

    -- The Import button is disabled with no provider registered, so this is belt and
    -- braces rather than a path a user can reach.
    if not provider_id then return end

    import_encoded_softres_data( edit_box_text, provider_id, function()
      local result = softres_check.check_softres()

      if result ~= softres_check.ResultType.NoItemsFound then
        softres_data = edit_box_text
        softres.persist( softres_data, provider_id )
        close_window_fn()
        reset_loot_announcements()
      end
    end )
  end

  local function on_clear()
    edit_box_text = nil
    softres_data = nil
    dirty = false

    if frame then
      frame.editbox:SetText( "" )
      if has_providers() then frame.editbox:SetFocus() end
    end

    clear_data()
    reset_loot_announcements()
  end

  local function on_cancel()
    edit_box_text = softres_data
    dirty = false
    return softres_data
  end

  local function on_dirty( import_button, clear_button, cancel_button )
    if locked() then
      cancel_button:SetText( "Close" )
      import_button:Disable()
      clear_button:Disable()
      return
    end

    local text = frame.editbox:GetText()
    if text == "" then text = nil end

    if edit_box_text ~= text then
      dirty = true
      edit_box_text = text
    end

    cancel_button:SetText( dirty and "Cancel" or "Close" )

    -- Nothing registered a decoder, so there is nothing Import could do with the paste.
    -- Clear is left alone deliberately: wiping a list you can no longer decode is still
    -- your call to make.
    local importable = has_providers()

    if dirty then
      if not importable or edit_box_text == softres_data then
        import_button:Disable()
      else
        import_button:Enable()
      end

      clear_button:Enable()
      return
    end

    if text == nil then
      clear_button:Disable()
    else
      clear_button:Enable()
    end

    import_button:Disable()
  end

  local function toggle()
    if not frame then
      frame = create_frame( api, gui_elements, on_import, on_clear, on_cancel, on_dirty, inert, on_provider_change )
    end

    if frame:IsVisible() then
      frame:Hide()
    else
      dirty = false
      frame.editbox:SetText( softres_data or "" )
      apply_providers()
      apply_lock()

      frame:Show()

      if not locked() and has_providers() and (not softres_data or softres_data == "") then
        frame.editbox:SetFocus()
      end
    end
  end

  -- The simulator calls this when it starts, so a window that is already open locks
  -- itself instead of waiting to be reopened.
  local function refresh()
    if not frame then return end

    apply_providers()
    apply_lock()
    on_dirty( frame.import_button, frame.clear_button, frame.cancel_button )
  end

  local function load( data )
    softres_data = data
  end

  local function clear()
    edit_box_text = nil
    softres_data = nil
    dirty = false

    if frame then frame.editbox:SetText( "" ) end

    reset_loot_announcements()
  end

  return {
    toggle = toggle,
    load = load,
    clear = clear,
    refresh = refresh
  }
end

sr.SoftResGui = M
return M
