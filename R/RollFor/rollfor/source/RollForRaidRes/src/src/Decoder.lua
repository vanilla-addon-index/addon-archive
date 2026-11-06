RollForRaidRes = RollForRaidRes or {}
local sr = RollForRaidRes

if sr.Decoder then return end

local M = {}

-- Core's shared helpers. RollFor is guaranteed to be loaded: the TOC declares it as a
-- dependency, so the client refuses to load this addon without it.
local m = RollFor

---@diagnostic disable-next-line: undefined-global
local lib_stub = LibStub

-- base64 -> JSON. This is the whole of what "raidres" means to RollFor, and it is why the
-- import belongs in an addon rather than in core: nothing above this line has an opinion
-- about the wire format, and a different source site would replace this file and nothing
-- else.
--
-- There is no decompression step. A raidres export is plain base64 over JSON -- the first
-- two decoded bytes are `{"`, where a softres.it string carries a zlib header instead. The
-- consequence is intended: a softres.it string pasted into this window decodes as base64,
-- fails to parse as JSON, and is reported as data that could not be loaded.

-- Taragaman the Hungerer all SR by Jogobobek:
-- eyJtZXRhZGF0YSI6eyJpZCI6IjNRUzg1OCIsImluc3RhbmNlIjoxMDEsImluc3RhbmNlcyI6WyJLYXJhemhhbiJdLCJvcmlnaW4iOiJyYWlkcmVzIn0sInNvZnRyZXNlcnZlcyI6W3sibmFtZSI6IkpvZ29ib2JlayIsIml0ZW1zIjpbeyJpZCI6MTQxNDUsInF1YWxpdHkiOjN9LHsiaWQiOjE0MTQ4LCJxdWFsaXR5IjozfSx7ImlkIjoxNDE0OSwicXVhbGl0eSI6M31dfV0sImhhcmRyZXNlcnZlcyI6W119

-- Taragaman the Hungerer mix SR by Jogobobek and Guildhamster:
-- eyJtZXRhZGF0YSI6eyJpZCI6IlhTRUE5USIsImluc3RhbmNlIjo5NiwiaW5zdGFuY2VzIjpbIk5heHhyYW1hcyJdLCJvcmlnaW4iOiJyYWlkcmVzIn0sInNvZnRyZXNlcnZlcyI6W3sibmFtZSI6IkpvZ29ib2JlayIsIml0ZW1zIjpbeyJpZCI6MTQxNDUsInF1YWxpdHkiOjJ9LHsiaWQiOjE0MTQ1LCJxdWFsaXR5IjoyfSx7ImlkIjoxNDE0OCwicXVhbGl0eSI6Mn1dfSx7Im5hbWUiOiJPYnN6Y3p5bXVjaGEiLCJpdGVtcyI6W3siaWQiOjE0MTQ1LCJxdWFsaXR5IjoyfSx7ImlkIjoxNDE0OCwicXVhbGl0eSI6Mn0seyJpZCI6MTQxNDksInF1YWxpdHkiOjJ9XX1dLCJoYXJkcmVzZXJ2ZXMiOltdfQ==

-- Taragaman the Hungerer all SR by Jogobobek and Guildhamster:
-- eyJtZXRhZGF0YSI6eyJpZCI6IlNDRDNQMyIsImluc3RhbmNlIjo5NiwiaW5zdGFuY2VzIjpbIk5heHhyYW1hcyJdLCJvcmlnaW4iOiJyYWlkcmVzIn0sInNvZnRyZXNlcnZlcyI6W3sibmFtZSI6IkpvZ29ib2JlayIsIml0ZW1zIjpbeyJpZCI6MTQxNDUsInF1YWxpdHkiOjJ9LHsiaWQiOjE0MTQ4LCJxdWFsaXR5IjoyfSx7ImlkIjoxNDE0OSwicXVhbGl0eSI6Mn1dfSx7Im5hbWUiOiJPYnN6Y3p5bXVjaGEiLCJpdGVtcyI6W3siaWQiOjE0MTQ1LCJxdWFsaXR5IjoyfSx7ImlkIjoxNDE0OCwicXVhbGl0eSI6Mn0seyJpZCI6MTQxNDksInF1YWxpdHkiOjJ9XX1dLCJoYXJkcmVzZXJ2ZXMiOltdfQ==
---@param encoded_softres_data string?
---@return table? -- the decoded JSON, or nil with the reason already printed
function M.decode( encoded_softres_data )
  if not encoded_softres_data then return nil end

  local data = m.decode_base64( encoded_softres_data )

  if not data then
    m.pretty_print( "Couldn't decode softres data!", m.colors.red )
    return nil
  end

  local json = lib_stub( "Json-0.1.2" )
  local success, result = pcall( function() return json.decode( data ) end )
  if not success then return nil end

  return result
end

sr.Decoder = M
return M
