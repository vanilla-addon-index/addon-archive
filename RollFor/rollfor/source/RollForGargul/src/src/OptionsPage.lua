RollForGargul = RollForGargul or {}
local g = RollForGargul

if g.OptionsPage then return end

local M = {}

-- Core's shared helpers. RollFor is guaranteed to be loaded: the TOC declares it as a
-- dependency, so the client refuses to load this addon without it.
local m = RollFor

-- This addon's page in RollFor's options window.
--
-- RollFor creates the canvas and registers it with the game's settings panel, then hands it
-- over and asks this to fill it in. Core does not know what is on the page and does not want
-- to: an extension keeps its own database, so it is the only thing that knows what is worth
-- showing. What core does supply is the builders -- the popup builder, the frame builder and
-- the widget set -- so a page can be assembled out of the same pieces RollFor's own page uses
-- rather than out of raw CreateFrame calls.
--
-- This addon registers no settings, so there is nothing here but what it is for and the switch
-- that turns it on.

-- What this addon is for, in its own words. Core does not hold a copy: it has no use for one,
-- since this page is the only thing that shows it.
local SUMMARY =
    "Lets Gargul users in your raid see what RollFor is doing.\n" ..
    "Rolls you start show up in their Gargul window, so they can roll without reading chat.\n" ..
    "Answers Gargul's request for your soft-res data, and sends it out when you import.\n" ..
    "Does nothing on its own -- turn it off if nobody in your raid uses Gargul."

local SIDE_INSET, TOP_INSET = 16, 16

-- Vertical gap above each kind of line. Mirrors what RollFor uses on its own page so the two
-- look like one addon; nothing enforces that, and nothing has to.
local paddings = {
  section_header = 13,
  paragraph = 9,
  checkbox = 5
}

-- Prose is followed by a bigger gap than the one between two controls, so the checkbox
-- underneath reads as a new thought rather than the summary's last line.
local after_paragraph_padding = 16

-- No settings of its own: it either speaks to Gargul or it does not, and that is the Enabled
-- switch. The switch is core's, reached through ctx.is_enabled rather than through the config --
-- core only injects it onto the page it draws for an extension that supplies none of its own, so
-- a page like this one has to carry it.
--
-- Which is the whole reason this page exists. Without it the extension gets that bare page: a
-- lone checkbox with nothing saying what it turns on, for a feature whose name is another
-- addon's.

---@param ctx ExtensionContext
---@param parent table -- the canvas RollFor registered for this page
---@return { show: fun() }
function M.new( ctx, parent )
  local popup

  -- The summary is written a line per thought, so letting it wrap turns a list into prose:
  -- the continuation of a long line sits under the start of it and reads as another entry.
  -- Give it the width of the canvas it is actually in rather than the widget's own default,
  -- which is sized for a narrower page than the settings window.
  --
  -- Measured at show() rather than at build, because the settings window sizes the canvas
  -- when it displays the page. Falls back to whatever the widget chose if it is asked before
  -- then.
  local function paragraph_width( frame )
    local available = (parent.GetWidth and parent:GetWidth() or 0) - SIDE_INSET * 2

    return available > 0 and math.max( available, frame:GetWidth() or 0 ) or nil
  end

  local function create_popup()
    return ctx.popup_builder()
        :name( "RollForGargulOptionsPage" )
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
  end

  -- Chains each line under the one before it, left-aligned. The first line sits flush at the
  -- top of the page; the inset above already holds it off the panel edge.
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

  -- Rebuilt from scratch on every visit, because every checkbox on it has to show what is
  -- true now -- all of these can be changed from a slash command, or by another page,
  -- between one viewing and the next.
  local function show()
    if not popup then popup = create_popup() end

    popup:clear()

    add_line( "section_header", nil, function( frame )
      frame:SetText( m.colors.blue( "Summary" ) )
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

    popup:Show()
  end

  return {
    show = show,
    get_frame = function() return popup end
  }
end

g.OptionsPage = M
return M
