RollForSoftRes = RollForSoftRes or {}
local sr = RollForSoftRes

if sr.OptionsPage then return end

local hl = RollFor.colors.hl

local M = {}

-- This addon's page in RollFor's options window.
--
-- RollFor creates the canvas and registers it with the game's settings panel, then hands
-- it over and asks this to fill it in. Core does not know what is on the page and does not
-- want to: an extension keeps its own database, so it is the only thing that knows what is
-- worth showing. What core does supply is the builders -- the popup builder, the frame
-- builder, and the widget set -- so a page can be assembled out of the same pieces
-- RollFor's own page uses rather than out of raw CreateFrame calls.
--
-- The Enabled checkbox is ours too, wired to ctx.is_enabled / ctx.set_enabled. Core no
-- longer injects it.

-- What this addon is for, in its own words. Core does not hold a copy: it has no use for
-- one, since this page is the only thing that shows it.
local SUMMARY = string.format(
  "Provides core soft-res functionality. Soft-res data is provided by separate provider addons.\n\n" ..
  "%s - opens the import window\n" ..
  "%s - clears the soft-res data\n" ..
  "%s - checks who in the group has not reserved\n" ..
  "%s - shows the reserved items\n" ..
  "%s - fixes a player whose in-game name differs from the one they reserved under",
  hl( "/sr" ), hl( "/sr init" ), hl( "/src" ), hl( "/srs" ), hl( "/sro" )
)

local SIDE_INSET, TOP_INSET = 16, 16

-- Vertical gap above each kind of line. Mirrors what RollFor uses on its own page so the
-- two look like one addon; nothing enforces that, and nothing has to.
local paddings = {
  section_header = 13,
  paragraph = 9,
  checkbox = 5,
  slider = 10
}

-- Prose is followed by a bigger gap than the one between two controls, so the checkbox
-- underneath reads as a new thought rather than the summary's last line.
local after_paragraph_padding = 16

---@param ctx ExtensionContext
---@param parent table -- the canvas RollFor registered for this page
---@return { show: fun() }
function M.new( ctx, parent )
  local popup

  -- The summary is prose and is meant to wrap, but it has to wrap to the width of the
  -- canvas it is actually in rather than the widget's own default, which is sized for a
  -- narrower page than the settings window.
  --
  -- Measured at show() rather than at build, because the settings window sizes the canvas
  -- when it displays the page. Falls back to whatever the widget chose if it is asked
  -- before then.
  local function paragraph_width( frame )
    local available = (parent.GetWidth and parent:GetWidth() or 0) - SIDE_INSET * 2

    return available > 0 and math.max( available, frame:GetWidth() or 0 ) or nil
  end

  local function create_popup()
    local result = ctx.popup_builder()
        :name( "RollForSoftResOptionsPage" )
        :parent( parent )
        :point( {
          point = "TOPLEFT",
          relative_frame = parent,
          relative_point = "TOPLEFT",
          x = SIDE_INSET,
          y = -TOP_INSET
        } )
        :gui_elements( ctx.gui_elements )
        :backdrop_color( 0, 0, 0, 0 )
        :no_border()
        :build()

    return result
  end

  -- Chains each line under the one before it, left-aligned. The first line sits flush at
  -- the top of the page; the inset above already holds it off the panel edge.
  ---@param line_type string
  ---@param previous_type string?
  ---@param configure fun( frame: table )
  local function add_line( line_type, previous_type, configure )
    local padding = previous_type == nil and 0
        or previous_type == "paragraph" and after_paragraph_padding
        or paddings[ line_type ] or 5

    popup.add_line( line_type, function( _, frame, lines )
      configure( frame )

      local count = #lines
      frame:ClearAllPoints()

      if count == 0 then
        frame:SetPoint( "TOPLEFT", popup, "TOPLEFT", 0, -padding )
      else
        frame:SetPoint( "TOPLEFT", lines[ count ].frame, "BOTTOMLEFT", 0, -padding )
      end
    end, padding )
  end

  -- Rebuilt from scratch on every visit, because the Enabled checkbox has to show what is
  -- true now -- it can be changed from a slash command, or by another page, between one
  -- viewing and the next.
  local function show()
    if not popup then popup = create_popup() end

    popup:clear()

    add_line( "section_header", nil, function( frame )
      frame:SetText( RollFor.colors.blue( "Summary" ) )
    end )

    add_line( "paragraph", "section_header", function( frame )
      local width = paragraph_width( frame )
      if width then frame:SetWidth( width ) end

      frame:SetText( SUMMARY )
    end )

    add_line( "checkbox", "paragraph", function( frame )
      frame:SetText( "Enabled" )
      frame:SetChecked( ctx.is_enabled() )
      frame.on_click = function( value ) ctx.set_enabled( value ) end
    end )

    -- Registered in on_enable, read back through core's config like any other setting. The list
    -- window subscribes to it, so an open list redraws with the new limit straight away.
    local rows = sr.SoftResListFrame.rows_setting

    add_line( "slider", "checkbox", function( frame )
      frame:SetText( "Soft-res list rows" )
      frame:SetMinMaxValues( rows.min, rows.max )
      frame:SetPrecision( 0 )
      frame:SetValue( ctx.config[ rows.key ]() )
      frame.on_change = ctx.config[ "set_" .. rows.key ]
    end )

    popup:Show()
  end

  return {
    show = show,
    get_frame = function() return popup end
  }
end

sr.OptionsPage = M
return M
