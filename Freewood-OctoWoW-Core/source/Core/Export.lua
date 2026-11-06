-- Freewood-OctoWoW-Core: Export und Import als kurzer Code
--
-- Format:   FW1:<art>:<pruefsumme>:<koerper>
--   art           kleingeschriebene Datenart, z. B. "pets" oder "beasts"
--   pruefsumme    8 Hex-Zeichen ueber den Koerper (erkennt Tippfehler und abgeschnittene Codes)
--   koerper       Base64( Komprimiert( CBOR( { v, k, t, a, d } ) ) )
-- Das ist Komprimierung und Kodierung, keine Verschluesselung.
--
-- Sicherheit beim Import:
--   * Es wird nie Code ausgefuehrt, nur Daten gelesen (CBOR).
--   * Groessenlimit, Tiefenlimit, Knotenlimit, nur Text/Zahl/Wahrheitswert/Tabelle.
--   * Das zustaendige Modul prueft die Daten zusaetzlich (validate) und fuegt sie
--     selbst zusammen (import). Regel fuer Module: importierte Eintraege mit
--     src = "import" markieren und eigene Daten nie ueberschreiben.
--
-- Ein Modul meldet sich so an:
--   Freewood.Export.RegisterHandler("pets", {
--       label    = "Jaeger-Begleiter" (Text oder Funktion),
--       export   = function() return <Tabelle> end,
--       validate = function(data, payload) return true end,   -- optional
--       import   = function(data, payload) return "3 neu, 1 ergaenzt" end,
--   })

local ADDON, FW = ...

local Export = {}
FW.Export = Export

local Util = FW.Util

local FORMAT_VERSION = 1
local MAX_ENCODED = 150000
local HARD_MAX = 400000   -- groesstes erlaubtes Limit eines Handlers (handler.maxEncoded)

local LIMITS = {
    maxDepth = 12,
    maxNodes = 200000,
    maxString = 4096,
}

Export.handlers = {}
Export.handlerList = {}

function Export.RegisterHandler(kind, handler)
    assert(type(kind) == "string" and kind:match("^[a-z0-9]+$"),
        "Freewood.Export: Datenart muss aus a-z und 0-9 bestehen")
    assert(type(handler) == "table", "Freewood.Export: Handler fehlt")
    handler.kind = kind
    if not Export.handlers[kind] then
        Export.handlerList[#Export.handlerList + 1] = handler
    else
        for i, h in ipairs(Export.handlerList) do
            if h.kind == kind then
                Export.handlerList[i] = handler
            end
        end
    end
    Export.handlers[kind] = handler
end

function Export.GetLabel(handler)
    local label = handler.label
    if type(label) == "function" then
        label = label()
    end
    return label or handler.kind
end

local function GetEncoder()
    local E = C_EncodingUtil
    if E and E.SerializeCBOR and E.DeserializeCBOR and E.CompressString
        and E.DecompressString and E.EncodeBase64 and E.DecodeBase64 then
        return E
    end
    return nil
end

-- Prueft eine entpackte Datenstruktur auf harmlose Form.
function Export.CheckStructure(data)
    if type(data) ~= "table" then
        return false
    end
    local nodes = 0
    local seen = {}
    local stack = { { data, 1 } }

    while #stack > 0 do
        local entry = table.remove(stack)
        local tbl, depth = entry[1], entry[2]
        if depth > LIMITS.maxDepth or seen[tbl] then
            return false
        end
        seen[tbl] = true

        for k, v in pairs(tbl) do
            nodes = nodes + 1
            if nodes > LIMITS.maxNodes then
                return false
            end

            local kt = type(k)
            if kt ~= "string" and kt ~= "number" then
                return false
            end
            if kt == "string" and #k > LIMITS.maxString then
                return false
            end

            local vt = type(v)
            if vt == "string" then
                if #v > LIMITS.maxString then
                    return false
                end
            elseif vt == "number" then
                if v ~= v or v == math.huge or v == -math.huge then
                    return false
                end
            elseif vt == "table" then
                stack[#stack + 1] = { v, depth + 1 }
            elseif vt ~= "boolean" then
                return false
            end
        end
    end
    return true
end

-- Erzeugt den Code. Rueckgabe: text  oder  nil, fehlerSchluessel
function Export.Encode(kind, data)
    local E = GetEncoder()
    if not E then
        return nil, "ERR_NOAPI"
    end
    if type(kind) ~= "string" or not kind:match("^[a-z0-9]+$") or type(data) ~= "table" then
        return nil, "ERR_INVALID"
    end

    local payload = { v = FORMAT_VERSION, k = kind, t = time(), a = FW.version, d = data }

    local ok, cbor = pcall(E.SerializeCBOR, payload)
    if not ok or type(cbor) ~= "string" then
        return nil, "ERR_INVALID"
    end
    local ok2, packed = pcall(E.CompressString, cbor)
    if not ok2 or type(packed) ~= "string" then
        return nil, "ERR_INVALID"
    end
    local ok3, body = pcall(E.EncodeBase64, packed)
    if not ok3 or type(body) ~= "string" then
        return nil, "ERR_INVALID"
    end
    local hLimit = Export.handlers[kind] and tonumber(Export.handlers[kind].maxEncoded) or MAX_ENCODED
    if #body > math.min(hLimit, HARD_MAX) then
        return nil, "ERR_TOO_LARGE"
    end

    return string.format("FW%d:%s:%s:%s", FORMAT_VERSION, kind, Util.Hash(body), body)
end

-- Liest einen Code. Rueckgabe: payload  oder  nil, fehlerSchluessel
function Export.Decode(text)
    if type(text) ~= "string" then
        return nil, "ERR_FORMAT"
    end
    text = text:gsub("%s+", "")
    if text == "" then
        return nil, "ERR_FORMAT"
    end
    if #text > HARD_MAX + 64 then
        return nil, "ERR_TOO_LARGE"
    end

    local version = text:match("^FW(%d+):")
    if not version then
        return nil, "ERR_FORMAT"
    end
    if tonumber(version) > FORMAT_VERSION then
        return nil, "ERR_VERSION"
    end

    local kind, crc, body = text:match("^FW%d+:([a-z0-9]+):(%x%x%x%x%x%x%x%x):(.+)$")
    if not kind then
        return nil, "ERR_FORMAT"
    end
    if body:find("[^%w%+/=_%-]") then
        return nil, "ERR_FORMAT"
    end
    local hl = Export.handlers[kind] and tonumber(Export.handlers[kind].maxEncoded) or MAX_ENCODED
    if #body > math.min(hl, HARD_MAX) then
        return nil, "ERR_TOO_LARGE"
    end
    if Util.Hash(body) ~= crc:lower() then
        return nil, "ERR_CHECKSUM"
    end

    local E = GetEncoder()
    if not E then
        return nil, "ERR_NOAPI"
    end

    local ok, packed = pcall(E.DecodeBase64, body)
    if not ok or type(packed) ~= "string" then
        return nil, "ERR_DECODE"
    end
    local ok2, cbor = pcall(E.DecompressString, packed)
    if not ok2 or type(cbor) ~= "string" then
        return nil, "ERR_DECODE"
    end
    local ok3, payload = pcall(E.DeserializeCBOR, cbor)
    if not ok3 or type(payload) ~= "table" then
        return nil, "ERR_DECODE"
    end

    if payload.v ~= FORMAT_VERSION then
        if type(payload.v) == "number" and payload.v > FORMAT_VERSION then
            return nil, "ERR_VERSION"
        end
        return nil, "ERR_INVALID"
    end
    if payload.k ~= kind or type(payload.d) ~= "table" then
        return nil, "ERR_INVALID"
    end
    if not Export.CheckStructure(payload.d) then
        return nil, "ERR_INVALID"
    end

    return payload
end

-- Exportiert die Daten eines Moduls. Rueckgabe: text  oder  nil, fehlerSchluessel, extra
function Export.ExportKind(kind)
    local handler = Export.handlers[kind]
    if not handler or not handler.export then
        return nil, "ERR_NO_HANDLER", kind
    end
    local ok, data = pcall(handler.export)
    if not ok or type(data) ~= "table" then
        return nil, "ERR_INVALID"
    end
    if next(data) == nil then
        return nil, "EXCHANGE_NOTHING_EXPORT"
    end
    -- encodeAs: ein Handler darf unter der Art eines anderen Handlers exportieren (dann importiert dieser)
    return Export.Encode(handler.encodeAs or kind, data)
end

-- Importiert einen Code ueber das zustaendige Modul.
-- Rueckgabe: true, statistik, art   oder   false, fehlerSchluessel, extra
function Export.Import(text)
    local payload, err = Export.Decode(text)
    if not payload then
        return false, err
    end

    local handler = Export.handlers[payload.k]
    if not handler or not handler.import then
        return false, "ERR_NO_HANDLER", payload.k
    end

    if handler.validate then
        local ok, valid, message = pcall(handler.validate, payload.d, payload)
        if not ok or not valid then
            return false, "ERR_INVALID", type(message) == "string" and message or nil
        end
    end

    local ok, result = pcall(handler.import, payload.d, payload)
    if not ok then
        FW:Debug("Import fehlgeschlagen:", result)
        return false, "ERR_INVALID"
    end
    return true, result, payload.k
end
