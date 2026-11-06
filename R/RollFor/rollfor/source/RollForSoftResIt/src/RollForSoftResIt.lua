RollForSoftResIt = RollForSoftResIt or {}
local sr = RollForSoftResIt

-- The softres.it wire format, and nothing else.
--
-- This addon is a **data provider** for RollForSoftRes. That addon owns the soft-res list,
-- the import window, the name matching, /sr and the registration with core's SoftResSource;
-- what it does not own is any opinion about base64, so a provider supplies one `decode` and
-- is otherwise absent.
--
-- It creates no frames, claims no slash commands, adds nothing to any chain, subscribes to
-- nothing, and never touches SoftResSource. That is exactly what lets it and
-- RollForRaidRes be installed at the same time -- which they could not be before, when
-- each carried a whole copy of the soft-res addon and the alphabet decided which one won.
--
-- Two registrations, in two places:
--
--   * with `Extensions`, at file scope, so this shows up in RollFor's options window with
--     its own page and its own Enabled checkbox, and reports its version through
--     `X-RollFor-Extension` like any other extension;
--   * with `RollForSoftRes`, from `on_enable`, which is what puts "softres.it" in the
--     import window's Provider dropdown.

local M = {}

-- Core's shared helpers. The TOC declares `## Dependencies: RollFor, RollForSoftRes` and
-- the client refuses to load this addon without both. RollFor is named as well as implied
-- by the library, so unticking it in the addon list disables this one directly.
local m = RollFor

-- Handed over from on_enable, not from file scope and not from on_ready.
--
-- Not file scope, because a **disabled** extension never gets on_enable, and that is
-- precisely what keeps a disabled provider out of the dropdown -- no extra bookkeeping, no
-- flag to keep in step with the checkbox.
--
-- Not on_ready either: the TOC chain loads RollForSoftRes first, so its on_ready runs
-- before this one, and it builds the window there. A decoder handed over from on_ready
-- would arrive after the window that needs it.
local function on_enable()
  if not RollForSoftRes or not RollForSoftRes.register then
    m.warn( "Unsupported RollForSoftRes version.", "RollForSoftResIt" )
    return
  end

  RollForSoftRes.register( {
    -- Same string as the extension name and as X-RollFor-Extension. It is saved with an
    -- imported list to say which decoder produced it, so it has to be stable.
    id = "softres_it",
    -- The site, because that is the question the dropdown is asking. The extension title --
    -- "SR Provider (softres.it)" -- names a page in the options tree, which is a different
    -- question.
    title = "softres.it",
    decode = sr.Decoder.decode
  } )
end

M.on_enable = on_enable

function M.register()
  if not m.Extensions then
    m.warn( "Unsupported RollFor version.", "RollForSoftResIt" )
    return
  end

  return m.Extensions.register( {
    name = "softres_it",
    title = "SR Provider (softres)",
    -- 2, not Extensions.API_VERSION: this is what the addon was written against, and
    -- claiming whatever core happens to be at would be a promise it cannot keep.
    api_version = 2,
    default_enabled = true,
    on_enable = on_enable,

    -- Declared here rather than from on_enable because a disabled extension still needs
    -- its page -- that page is where the switch to turn it back on lives, and on_enable
    -- does not run when we are off.
    options_page = function( ctx, parent ) return sr.OptionsPage.new( ctx, parent ) end
  } )
end

sr.main = M

M.register()

return M
