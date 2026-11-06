-- Freewood-OctoWoW-Core: Grundgeruest
-- Namensraum, Ereignissystem, Modulverwaltung, Datenspeicher.
-- Andere Addons der Familie greifen ueber die globale Variable "Freewood" darauf zu.

local ADDON, FW = ...

_G.Freewood = FW

FW.ADDON = ADDON

-- OctoWoW-Fassung (Port von Freewood 0.56.0, das fuer "Forever" geschrieben wurde).
-- testBypass: NUR fuer die Testfassungen. Umgeht die Berechtigungsliste (Dev-Sperre), damit wir alles pruefen koennen.
-- Zum Abschalten: testBypass = false (eine Stelle, gilt fuer alle Module).
FW.OCTO = { name = "OctoWoW", based = "Freewood 0.56.0", testBypass = false }

-- Fehler, die schon beim Laden der Dateien auftreten (bevor Freewood-OctoWoW-Dev da ist), werden hier gesammelt.
-- Freewood-OctoWoW-Dev holt sie spaeter ins Log (Dev.Probe).
FW.earlyErrors = {}
do
    local getH, setH = _G.geterrorhandler, _G.seterrorhandler
    if getH and setH then
        local old = getH()
        FW.earlyHandler = function(err)
            local s = tostring(err)
            if s:find("Freewood", 1, true) then
                local list = FW.earlyErrors
                if #list < 200 then
                    list[#list + 1] = { t = _G.GetTime and _G.GetTime() or 0, m = s }
                end
            end
            if old then
                return old(err)
            end
        end
        setH(FW.earlyHandler)
    end
end

FW.API_VERSION = 1   -- wird erhoeht, wenn sich die Modul-Schnittstelle inkompatibel aendert
FW.DB_VERSION = 1    -- Version des gespeicherten Datenformats

local function GetMeta(field)
    local fn = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if fn then
        local ok, value = pcall(fn, ADDON, field)
        if ok then
            return value
        end
    end
    return nil
end

FW.version = GetMeta("Version") or "dev"

------------------------------------------------------------------------
-- Ausgabe und Fehlerbehandlung
------------------------------------------------------------------------

local PREFIX = "|cffc89b3cFreewood|r"

local function Join(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring((select(i, ...)))
    end
    return table.concat(parts, " ")
end

function FW:Print(...)
    print(PREFIX .. ": " .. Join(...))
end

function FW:Debug(...)
    if self.db and self.db.settings and self.db.settings.debug then
        print(PREFIX .. " |cff8c8a84[debug]|r " .. Join(...))
    end
end

-- Ruft fn geschuetzt auf. Ein Fehler wird an den Standard-Fehlerhandler
-- weitergereicht und bricht den Aufrufer nicht ab.
local function SafeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        local handler = geterrorhandler and geterrorhandler()
        if handler then
            handler(err)
        else
            print(err)
        end
    end
    return ok
end
FW.SafeCall = SafeCall

------------------------------------------------------------------------
-- Interne Nachrichten (Ereignissystem des Cores)
------------------------------------------------------------------------

local callbacks = {}

function FW:On(event, fn, owner)
    local list = callbacks[event]
    if not list then
        list = {}
        callbacks[event] = list
    end
    list[#list + 1] = { fn = fn, owner = owner }
end

function FW:Off(event, owner)
    local list = callbacks[event]
    if not list then
        return
    end
    for i = #list, 1, -1 do
        if list[i].owner == owner then
            table.remove(list, i)
        end
    end
end

-- Zeitmesser-Haken (setzt das Dev-Modul): FW.ProfEnter(art, ereignis, eintrag) -> Tiefe oder nil, FW.ProfLeave(tiefe, art, ereignis, eintrag).
-- Ohne Dev-Modul kostet das je Aufruf nur eine nil-Pruefung. Die Haken laufen geschuetzt, ein Fehler dort bricht nichts ab.
function FW:Fire(event, ...)
    local list = callbacks[event]
    if not list then
        return
    end
    local snapshot = {}
    for i = 1, #list do
        snapshot[i] = list[i]
    end
    local enter, leave = FW.ProfEnter, FW.ProfLeave
    for i = 1, #snapshot do
        local cb = snapshot[i]
        local depth
        if enter then
            local ok, d = pcall(enter, "fire", event, cb)
            if ok then depth = d end
        end
        if cb.owner then
            SafeCall(cb.fn, cb.owner, ...)
        else
            SafeCall(cb.fn, ...)
        end
        if depth then pcall(leave, depth, "fire", event, cb) end
    end
end

------------------------------------------------------------------------
-- Spielereignisse (ein gemeinsamer Frame fuer alle Module)
------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local gameHandlers = {}
-- OctoWoW (1.12): Ereignis -> echte Ereignisse, die es dort gibt
local EVENT_ALIAS = {
    GROUP_ROSTER_UPDATE = { "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE" },
    PET_STATS_UPDATE = { "UNIT_HAPPINESS", "UNIT_PET_EXPERIENCE" },
}
local aliasTarget = {}

function FW:RegisterEvent(event, fn, owner)
    local list = gameHandlers[event]
    if not list then
        local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
        if not ok then
            self:Debug("Ereignis nicht verfuegbar:", event)
            return false
        end
        list = {}
        gameHandlers[event] = list
        -- OctoWoW: moderne Ereignisse, die der 1.12-Client nicht kennt, ueber die echten Ereignisse abbilden
        local alias = EVENT_ALIAS[event]
        if alias then
            for ai = 1, #alias do
                local real = alias[ai]
                if pcall(eventFrame.RegisterEvent, eventFrame, real) then
                    aliasTarget[real] = event
                end
            end
        end
    end
    list[#list + 1] = { fn = fn, owner = owner }
    return true
end

function FW:UnregisterEvent(event, owner)
    local list = gameHandlers[event]
    if not list then
        return
    end
    -- OctoWoW: while-Schleife statt "for i = #list, 1, -1" (die Rueckwaerts-Schleife lieferte hier nil-Eintraege)
    local i = #list
    while i >= 1 do
        local h = list[i]
        if h and h.owner == owner then
            table.remove(list, i)
        end
        i = i - 1
    end
    if #list == 0 then
        gameHandlers[event] = nil
        eventFrame:UnregisterEvent(event)
        local alias = EVENT_ALIAS[event]
        if alias then
            for ai = 1, #alias do
                if aliasTarget[alias[ai]] == event then
                    aliasTarget[alias[ai]] = nil
                    eventFrame:UnregisterEvent(alias[ai])
                end
            end
        end
    end
end

local curEvent
local function Dispatch(list, ...)
    local snapshot = {}
    for i = 1, #list do
        snapshot[i] = list[i]
    end
    -- Zeitmesser (Dev-Modul): siehe FW:Fire
    local enter, leave = FW.ProfEnter, FW.ProfLeave
    local event = curEvent
    for i = 1, #snapshot do
        local h = snapshot[i]
        local depth
        if enter then
            local ok, d = pcall(enter, "event", event, h)
            if ok then depth = d end
        end
        if h.owner then
            SafeCall(h.fn, h.owner, ...)
        else
            SafeCall(h.fn, ...)
        end
        if depth then pcall(leave, depth, "event", event, h) end
    end
end

-- Von der Kanal-Schicht (Compat) genutzt: ein Ereignis wie vom Spiel an die angemeldeten Module geben
function FW:InjectEvent(event, ...)
    local list = gameHandlers[event]
    if list then
        curEvent = event
        Dispatch(list, ...)
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = gameHandlers[event]
    if list then
        curEvent = event
        Dispatch(list, ...)
    end
    local target = aliasTarget[event]
    if target and gameHandlers[target] then
        curEvent = event
        Dispatch(gameHandlers[target], ...)
    end
end)

------------------------------------------------------------------------
-- Datenspeicher
-- FreewoodDB      : gilt fuer den ganzen Account
-- FreewoodCharDB  : gilt nur fuer den aktuellen Charakter
-- Module legen ihre Daten unter db.modules[<Modulname>] ab (siehe NewModule).
------------------------------------------------------------------------

FW.defaults = {
    global = {
        dbVersion = FW.DB_VERSION,
        installed = 0,
        settings = {
            minimap = { hide = false, angle = 215 },
            scale = 1,
            locale = "auto",
            debug = false,
            whisperPopup = true,
            whisperPopupAlways = false,
            windowPos = false,
            windowSize = false,
        },
        disabledModules = {},
        modules = {},
    },
    char = {
        dbVersion = FW.DB_VERSION,
        modules = {},
    },
}

-- Migrationen: FW.migrations[n] hebt Daten von Version n-1 auf n.
FW.migrations = {}

local function Migrate(db, kind)
    local from = tonumber(db.dbVersion) or 0
    for version = from + 1, FW.DB_VERSION do
        local migration = FW.migrations[version]
        if migration then
            SafeCall(migration, db, kind)
        end
    end
    db.dbVersion = FW.DB_VERSION
end

function FW:InitDB()
    if type(FreewoodDB) ~= "table" then
        FreewoodDB = {}
    end
    if type(FreewoodCharDB) ~= "table" then
        FreewoodCharDB = {}
    end

    self.dbNewer = false

    local sets = {
        { db = FreewoodDB, defaults = self.defaults.global, kind = "global" },
        { db = FreewoodCharDB, defaults = self.defaults.char, kind = "char" },
    }

    for _, set in ipairs(sets) do
        local db = set.db
        local fresh = next(db) == nil
        local stored = tonumber(db.dbVersion)

        if fresh then
            db.dbVersion = self.DB_VERSION
        elseif stored and stored > self.DB_VERSION then
            -- Daten einer neueren Version: nichts migrieren, nichts abwerten.
            self.dbNewer = true
        else
            Migrate(db, set.kind)
        end

        self.Util.MergeDefaults(db, set.defaults)
    end

    if FreewoodDB.installed == 0 then
        FreewoodDB.installed = time()
    end

    self.db = FreewoodDB
    self.settings = FreewoodDB.settings
    self.chardb = FreewoodCharDB
end

function FW:ApplyLocale()
    local setting = self.settings and self.settings.locale or "auto"
    local code
    if setting == "deDE" or setting == "enUS" then
        code = setting
    else
        code = (GetLocale() == "deDE") and "deDE" or "enUS"
    end
    self:SetLocale(code)
end

------------------------------------------------------------------------
-- Module
-- Ablauf eines Moduls: NewModule -> OnInitialize (einmal, Daten bereit)
--                      -> OnEnable (nach PLAYER_LOGIN) -> optional OnDisable
------------------------------------------------------------------------

FW.modules = {}
FW.moduleList = {}

function FW:RequireAPI(minVersion, who)
    if (self.API_VERSION or 0) >= minVersion then
        return true
    end
    self:Print(string.format(self.L.API_TOO_OLD, tostring(who or "?"), minVersion, self.API_VERSION))
    return false
end

function FW:NewModule(name, opts)
    assert(type(name) == "string" and name ~= "", "Freewood:NewModule - Name fehlt")
    if self.modules[name] then
        error("Freewood: Modul '" .. name .. "' ist bereits registriert", 2)
    end

    local mod = opts or {}
    mod.name = name
    mod.state = "registered"
    mod.core = self

    function mod:IsEnabled()
        return self.state == "enabled"
    end

    self.modules[name] = mod
    self.moduleList[#self.moduleList + 1] = mod

    if self.ready then
        self:InitModule(mod)
        if self.loggedIn then
            self:EnableModule(mod)
        end
    end

    self:Fire("FW_MODULE_REGISTERED", mod)
    return mod
end

function FW:GetModule(name)
    return self.modules[name]
end

function FW:InitModule(mod)
    if mod.state ~= "registered" then
        return
    end

    local globalData = self.db.modules
    local charData = self.chardb.modules
    globalData[mod.name] = globalData[mod.name] or {}
    charData[mod.name] = charData[mod.name] or {}

    if mod.defaults then
        self.Util.MergeDefaults(globalData[mod.name], mod.defaults)
    end
    if mod.charDefaults then
        self.Util.MergeDefaults(charData[mod.name], mod.charDefaults)
    end

    mod.db = globalData[mod.name]
    mod.chardb = charData[mod.name]
    mod.state = "initialized"

    if mod.OnInitialize then
        SafeCall(mod.OnInitialize, mod)
    end
end

function FW:EnableModule(mod)
    if mod.state ~= "initialized" and mod.state ~= "disabled" then
        return
    end
    if self.db.disabledModules[mod.name] then
        mod.state = "disabled"
        return
    end
    mod.state = "enabled"
    if mod.OnEnable then
        SafeCall(mod.OnEnable, mod)
    end
    self:Fire("FW_MODULE_ENABLED", mod)
end

function FW:DisableModule(mod)
    if mod.state ~= "enabled" then
        return
    end
    mod.state = "disabled"
    if mod.OnDisable then
        SafeCall(mod.OnDisable, mod)
    end
end

function FW:SetModuleEnabled(name, enabled)
    local mod = self.modules[name]
    self.db.disabledModules[name] = (not enabled) or nil
    if mod then
        if enabled then
            self:EnableModule(mod)
        else
            self:DisableModule(mod)
        end
    end
end

------------------------------------------------------------------------
-- Start
------------------------------------------------------------------------

function FW:OnAddonLoaded(name)
    if name ~= ADDON then
        return
    end
    self:UnregisterEvent("ADDON_LOADED", self)

    self:InitDB()
    self:ApplyLocale()
    self.ready = true

    if self.dbNewer then
        self:Print(self.L.DB_NEWER)
    end

    self:Fire("FW_DB_READY")

    -- Module, die vor der Datenbank registriert wurden (sollte nicht vorkommen)
    for _, mod in ipairs(self.moduleList) do
        self:InitModule(mod)
    end
end

function FW:OnLogin()
    self.loggedIn = true
    self:Fire("FW_LOGIN")
    for _, mod in ipairs(self.moduleList) do
        self:InitModule(mod)
        self:EnableModule(mod)
    end
end

FW:RegisterEvent("ADDON_LOADED", FW.OnAddonLoaded, FW)
FW:RegisterEvent("PLAYER_LOGIN", FW.OnLogin, FW)
