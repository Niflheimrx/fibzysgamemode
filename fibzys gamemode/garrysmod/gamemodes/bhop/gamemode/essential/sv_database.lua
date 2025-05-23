--[[~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	💾 Bunny Hop MySQL Data Handler
		by: fibzy (www.steamcommunity.com/id/fibzy_)

		file: sv_database.lua
		desc: Handles database interactions and data storage for Bunny Hop.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~]]

SQL = SQL or {}
SQL.Available = true

-- Change via server.cfg instead
CreateConVar("sv_sql_host", "localhost", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "The SQL host address")
CreateConVar("sv_sql_user", "root", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "The SQL username")
CreateConVar("sv_sql_pass", "password", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "The SQL password")
CreateConVar("sv_sql_db", "mydatabase", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "The SQL database name")
CreateConVar("sv_sql_port", "3306", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "The SQL port")

local SQLObject
local SQLDetails = {
    Host = GetConVar("sv_sql_host"):GetString(),
    User = GetConVar("sv_sql_user"):GetString(),
    Pass = GetConVar("sv_sql_pass"):GetString(),
    Database = GetConVar("sv_sql_db"):GetString(),
    Port = GetConVar("sv_sql_port"):GetInt()
}

-- Use MySQL for true (sqllite not supported)
SQL.Use = true

MySQL = MySQL or {}
MySQL.queries = {}

-- Cache
local gp, gt, gn, gs, Iv = pairs, type, tonumber, tostring, IsValid
local ss, sl, sg, slc = string.sub, string.len, string.gsub, string.lower
local sqstr, sq, lqe = sql.SQLStr, sql.Query

UI, DATA = {}, {}

-- If no mysqloo found
local success, err = pcall(require, "mysqloo")
if not success then
    SQL.Use = false
    SQL.Available = false
    UTIL:Notify(Color(255, 0, 0), "Database", "MySQLoo module not found. Switching to fallback mode.")
    UTIL:Notify(Color(255, 0, 0), "Database", "Detailed error: " .. err)
else
    UTIL:Notify(Color(0, 255, 0), "Database", "MySQLoo module successfully loaded.")
end

-- Fonts
resource.AddFile("resource/fonts/FiBuchetMS-Bold.ttf") -- CS:S Hud
resource.AddFile("resource/fonts/Verdana.ttf") -- Other

BHDATA = BHDATA or {}
BHDATA.Protocol = "TimerNetworkProtocol"
BHDATA.Protocol2 = "BinaryTransfer"

MapGlobals = MapGlobals or {}

-- Load main data
function TIMER:Boot()
    if Command and Command.Init then
        Command:Init()
    end

    if RTV and RTV.Init then
        RTV:Init()
    end

    self:LoadZones()
    self:LoadRecords()
    self:LoadTop()
    self:AddPlays()

    if Admin and Admin.LoadAdmins then
        Admin:LoadAdmins()
    end

    BHDATA:Optimize()

    MapGlobals:GetGlobalWRForMap(game.GetMap(), function(globalWR)
        BHDATA.globalWR = globalWR
    end)
end

-- Reload zones for admins
function ReloadZonesOnMapLoad()
    Zones.Cache = {}
    Zones:ClearEntities()

    TIMER:LoadZones(function(success)
        if success then
            if Zones and Zones.Setup then
                Zones:Setup()
                UTIL:Notify(Color(255, 0, 0), "Database", "Zones successfully reloaded!")
            else
                UTIL:Notify(Color(255, 0, 0), "Database", "Zones function does NOT exist!")
            end
        else
             UTIL:Notify(Color(255, 0, 0), "Database", "No zones found cannot reload!")
        end
    end)
end

-- Unload everything
function BHDATA:Unload(force)
    if Replay and Replay.Save then
        Replay:Save(force)
    end
end

local function ToVec(str)
    str = sg(str, " ", ",")
    
    local v = string.Explode(",", str)
    if #v == 3 then
        return Vector(gn(v[1]), gn(v[2]), gn(v[3]))
    else
        return Vector(0, 0, 0)
    end
end

local function ToAng(str)
    local a = string.Explode(",", str)
    if #a == 3 then
        return Angle(gn(a[1]), gn(a[2]), gn(a[3]))
    else
        return Angle(0, 0, 0)
    end
end

local playerCache = {}
local cacheExpiration = 300

-- Stats WiP
function GetPlayerStats(playerID, callback)
    local cachedData = playerCache[playerID]
    for k, v in gp(playerCache) do
        if v.expiration <= CurTime() then
            playerCache[k] = nil
        end
    end
    
    if cachedData and cachedData.expiration > CurTime() then
        callback(cachedData.data)
    else
        local query = SQL:Prepare("SELECT * FROM player_stats WHERE player_id = {0}", {playerID})
        MySQL:Start(query, function(data)
            if data then
                playerCache[playerID] = {
                    data = data,
                    expiration = CurTime() + cacheExpiration
                }
                callback(data)
            else
                callback(nil)
            end
        end)
    end
end

SQL.ZonesLoaded = false

-- Load all zones for each map
function TIMER:LoadZones(callback)
    Zones.Cache = {}

    local map = game.GetMap()

    if not SQL.Use then
        UTIL:Notify(Color(255, 255, 0), "Database", "[Fallback] Skipping Load Zones — MySQL is disabled.")
        if callback then callback(false) end
        return
    end

    local sanitizedMap = SQL:Prepare("{0}", {map})
    if not sanitizedMap.Query then
        UTIL:Notify(Color(0, 255, 0), "Database", "Prepared Query SQL query for zones!")
        if callback then callback(false) end
        return
    end

    local query = "SELECT type, pos1, pos2 FROM timer_zones WHERE map = " .. sanitizedMap.Query

    MySQL:Start(query, function(zones)
        if not zones or #zones == 0 then
            UTIL:Notify(Color(255, 0, 0), "Database", "No zones found for this map: " .. map)
            if callback then callback(false) end
            return
        end

        UTIL:Notify(Color(0, 255, 0), "Database", "Found " .. #zones .. " zones for map: " .. map)
        for _, data in pairs(zones) do
            local zoneType = tonumber(data["type"])
            local pos1Str = data["pos1"]
            local pos2Str = data["pos2"]

            local pos1 = ToVec(pos1Str)
            local pos2 = ToVec(pos2Str)

            if zoneType and pos1 and pos2 then
                table.insert(Zones.Cache, {
                    Type = zoneType,
                    P1 = pos1,
                    P2 = pos2
                })
            else
                UTIL:Notify(Color(255, 0, 0), "Database", "Invalid zone data encountered.")
            end
        end

        SQL.ZonesLoaded = true
        UTIL:Notify(Color(0, 255, 0), "Database", "Zones loaded into cache")

        if callback then callback(true) end
    end)
end

-- Global Records
function MapGlobals:RegisterRecord(client, map, time)
    local steamID = client:SteamID()
    local playerName = client:Nick()
    local mapName = map
    local recordTime = time
    local date = os.date("%Y-%m-%d %H:%M:%S")

    local query = SQL:Prepare("INSERT INTO timer_global (map, player, time, date) VALUES ({0}, {1}, {2}, {3})", {mapName, playerName, recordTime, date})
    MySQL:Start(query.Query)
end

local cachedRecords = {}

-- Used for GWRs Formant
local function millisecondsToTime(ms)
    local floor, format = math.floor, string.format
    local minutes = floor(ms / 60000)
    local seconds = floor((ms % 60000) / 1000)
    local milliseconds = ms % 1000

    return format("%02d:%02d.%03d", minutes, seconds, milliseconds)
end

-- Get GWRs
function MapGlobals:GetGlobalWRForMap(map, callback)
    if cachedRecords[map] then
        callback(cachedRecords[map])
    else
        local query = "SELECT player, time FROM timer_global WHERE map = '" .. map .. "' LIMIT 1"
        MySQL:Start(query, function(data)
            if data and #data > 0 then
                local playerName = data[1].player
                local recordTime = data[1].time
  
                local formattedTime = millisecondsToTime(recordTime)
                cachedRecords[map] = playerName .. " - " .. formattedTime
                callback(cachedRecords[map])
            else
                callback("N/A")
            end
        end)
    end
end

function MapGlobals:SendGlobalWRToClient(client, map)
    MapGlobals:GetGlobalWRForMap(map, function(globalWR)
        local encodedData = NETWORK:Encode({ wr = globalWR, map = map })
        local len = #encodedData

        NETWORK:StartNetworkMessage(client, "SendWRData", client, map, globalWR)
    end)
end

hook.Add("PlayerInitialSpawn", "SendGlobalWROnJoin", function(client)
    MapGlobals:SendGlobalWRToClient(client, game.GetMap())
end)

-- Optimize Database sending
function BHDATA:Optimize()
    local function clearUnusedData()
        if Zones.Cache then
            for k, v in gp(Zones.Cache) do
                if not v.Type or not v.P1 or not v.P2 then
                    Zones.Cache[k] = nil
                end
            end
        end

        if Timer.Data then
            for k, v in gp(Timer.Data) do
                if not v.Time or not v.Player then
                    Timer.Data[k] = nil
                end
            end
        end
    end

    local function optimizeNetwork()
        local bytesWritten = net.BytesWritten()
        if bytesWritten and (bytesWritten > 1024 or bytesWritten > 4096) then
            net.SendOmit()
        end
    end

    clearUnusedData()
    optimizeNetwork()

    UTIL:Notify(Color(0, 255, 0), "Database", "Optimization completed.")
end

-- GC Debug
local function PrintLuaMemoryUsage()
    local memoryUsageKB = collectgarbage("count")
    local message = string.format("Lua memory usage: %.2f KB", memoryUsageKB)
    UTIL:Notify(Color(255, 0, 0), "Memory", message)
end

PrintLuaMemoryUsage()

-- Retry connection if fails
function TIMER:DBRetry(retryCount)
    retryCount = retryCount or 0
    local maxRetries = 3

    if retryCount == 0 then
        local success, err = pcall(function()
            if BHDATA and BHDATA.StartSQL then
                BHDATA:StartSQL()
            end
        end)

        if not success then
            UTIL:Notify(Color(255, 0, 0), "Database", "[ERROR] SQL/Admin startup failed: " .. err)
            retryCount = retryCount + 1
            if retryCount <= maxRetries then
                UTIL:Notify(Color(255, 0, 0), "Database", "[DEBUG] Retrying SQL/Admin load... Attempt: " .. retryCount)
                timer.Simple(2, function() self:DBRetry(retryCount) end)
            else
                UTIL:Notify(Color(255, 0, 0), "Database", "[ERROR] Max retries reached for SQL/Admin load.")
            end
            return
        end
    end

    if SQL and not SQL.Use then
        UTIL:Notify(Color(255, 0, 0), "Database", "[WARNING] MySQL is disabled, using fallback mode.")
        if SQL.LoadNoMySQL then
            SQL:LoadNoMySQL()
        end
        return
    end

    if Zones and Zones.Cache and #Zones.Cache > 0 then
        local success, err = pcall(function()
            if Zones.Setup then
                Zones:Setup()
                UTIL:Notify(Color(0, 255, 0), "Database", "Zones successfully setup!")
            end
        end)
        if not success then
            retryCount = retryCount + 1
            if retryCount <= maxRetries then
                UTIL:Notify(Color(0, 255, 0), "Database", "Retrying zone setup... Attempt: " .. retryCount)
                timer.Simple(2, function() self:DBRetry(retryCount) end)
            else
                UTIL:Notify(Color(255, 0, 0), "Database", "Max retries reached for Zones")
            end
            return
        end
    else
        UTIL:Notify(Color(0, 255, 0), "Database", "Loading zones load from DB...")
        self:LoadZones(function(success)
            if success then
                timer.Simple(0.5, function()
                    self:DBRetry(retryCount)
                end)
            else
                retryCount = retryCount + 1
                if retryCount <= maxRetries then
                    UTIL:Notify(Color(0, 255, 0), "Database", "Retrying zone load... Attempt: " .. retryCount)
                    timer.Simple(2, function() self:DBRetry(retryCount) end)
                else
                    UTIL:Notify(Color(255, 0, 0), "Database", "Max retries reached for Load Zones")
                end
            end
        end)
        return
    end

    if BHDATA and BHDATA.Optimize then
        BHDATA:Optimize()
    end
end

-- Start up
function BHDATA:StartSQL()
    if not SQL or not SQL.Use then return end

    local function onComplete()
        if Admin then
            if Admin.LoadAdmins then
                Admin:LoadAdmins()
            end
            if Admin.LoadNotifications then
                Admin:LoadNotifications()
            end
        end
        BHDATA.SQLChecking = nil
    end

    if SQL.CreateObject then
        SQL:CreateObject(onComplete)
    end
    
    BHDATA.SQLChecking = nil
end

function BHDATA.SQLCheck()
    if not SQL.Use then return end

    if (not Admin.Loaded or SQL.Error) and not BHDATA.SQLChecking then
        SQL.Error = nil
        BHDATA.SQLChecking = true
        BHDATA:StartSQL()
    end
end

-- Assert each table needed
function TIMER:Assert(result, key)
    if type(result) == "table" and type(result[1]) == "table" then
        return result[1][key] ~= nil
    end
    return false
end

function TIMER:Null(varInput, varAlternate)
    if type(varInput) ~= "string" then return varAlternate end
    return (varInput ~= "NULL") and varInput or varAlternate
end

function BHDATA:Send(ply, network, varArgs)
    net.Start(BHDATA.Protocol)
    net.WriteString(network)

    if varArgs and type(varArgs) == "table" then
        net.WriteBit(true)
        net.WriteTable(varArgs)
    else
        net.WriteBit(false)
    end

    net.Send(ply)
end

-- Broadcast messages
function BHDATA:Broadcast(network, varArgs, varExclude)
    if type(network) ~= "string" then
        UTIL:Notify(Color(255, 0, 0), "Database", "[ERROR] Broadcast: Action must be a string. Got: ", type(szAction))
        return
    end

    net.Start(BHDATA.Protocol)
    net.WriteString(network)

    if varArgs and type(varArgs) == "table" then
        net.WriteBit(true)
        net.WriteTable(varArgs)
    else
        net.WriteBit(false)
    end

    if varExclude then
        if type(varExclude) == "table" then
            net.SendOmit(varExclude)
        elseif Iv(varExclude) and varExclude:IsPlayer() then
            net.SendOmit(varExclude)
        else
            UTIL:Notify(Color(255, 0, 0), "Database", "[ERROR] Broadcast: Invalid var type.")
        end
    else
        net.Broadcast()
    end
end

-- Calls for Admin Speed WRList
local function coreHandle(ply, network, varArgs)
    if network == "Admin" then
        Admin:HandleClient(ply, varArgs)
	elseif network == "Speed" then
		TIMER:AddSpeedData(ply, varArgs)
	elseif network == "WRList" then
		TIMER:SendWRList(ply, varArgs[1], varArgs[2], varArgs[3])
    end
end

local function coreReceive(_, ply)
    local network = net.ReadString()
    local table = net.ReadBool()
    local varArgs = table and net.ReadTable() or {}

    if Iv(ply) and ply:IsPlayer() then
        coreHandle(ply, network, varArgs)
    end
end
net.Receive("TimerNetworkProtocol", coreReceive)

local function sqlConnectSuccess(callback)
    SQL.Available = true
    SQL.Busy = false
    callback()
end

local function sqlConnectFailure(_, err)
    SQL.Available = false
    SQL.Busy = false
    UTIL:Notify(Color(255, 0, 0), "SQL", "connection failed:", err)
end

local function sqlQuery(query, callback, args)
    local retries = 3
    local function executeQuery(retryCount)
        if retryCount <= 0 then
            return UTIL:Notify(Color(255, 0, 0), "SQLQuery", "Failed after retries: ", query)
        end
        local q = SQLObject:query(query)
        
        function q:onSuccess(data)
            if callback then callback(data, args) end
        end
        
        function q:onError(err)
                UTIL:Notify(Color(255, 0, 0), "Database", "[SQL Debug] Query error: " .. err)
            if ss(slc(err), 1, 4) == "lost" or ss(slc(err), 1, 8) == "gone away" then
                SQL.Error = true
                executeQuery(retryCount - 1)
            elseif callback then
                callback(nil, args, err)
            end
        end
        
        q:start()
    end
    executeQuery(retries)
    if not SQLObject or not SQL.Available then
        return UTIL:Notify(Color(255, 0, 0), "SQLObject", "No valid SQLObject to execute query: ", query)
    elseif not query or query == "" then
        return UTIL:Notify(Color(255, 0, 0), "SQLQuery", "No valid SQLQuery to execute.")
    end

    local q = SQLObject:query(query)
    
    function q:onSuccess(data)
        if callback then
            callback(data, args)
        end
    end
    
    function q:onError(err)
        if callback then
            callback(nil, args, err)
        end

        if ss(slc(err), 1, 4) == "lost" or ss(slc(err), 1, 8) == "gone away" then
            SQL.Error = true
            return false
        end
    end

    q:start()
end

-- Make sure admin loads always
local function WaitForAdmin(retries)
	retries = retries or 0
	if retries >= 5 then return end

	if not Admin or not Admin.LoadAdmins then
		timer.Simple(1, function()
			WaitForAdmin(retries + 1)
		end)
	else
		Admin:LoadAdmins()
	end
end

WaitForAdmin()

local function sqlExecute(query, callback, args)
    sqlQuery(query, function(data, varArgs, err)
        callback(data, varArgs, err)
    end, args)
end

-- Handle Database connected successfully
function SQL:CreateObject(callback)
    if not SQL.Use then
        UTIL:Notify(Color(255, 255, 0), "Database", "SQL disabled — skipping CreateObject.")
        return
    end

    SQL.Busy = true
    SQLObject = mysqloo.connect(SQLDetails.Host, SQLDetails.User, SQLDetails.Pass, SQLDetails.Database, SQLDetails.Port)

    function SQLObject:onConnected()
        UTIL:Notify(Color(0, 255, 0), "Database", "Database connected successfully!")

        if MySQL.StartUp then
            MySQL:StartUp()
        end
        MySQL:ProcessQueuedQueries()

        SQL.Busy = false
    end

    function SQLObject:onConnectionFailed(err)
        UTIL:Notify(Color(255, 0, 0), "Database", "Database connection FAILED: " .. err)
        SQL.Busy = false
    end

    SQLObject:connect()
end

-- Main Prepare
function SQL:Prepare(query, args, noQuote)
    if not SQLObject or not SQL.Available then
        UTIL:Notify(Color(255, 0, 0), "Database", "[ERROR] Database not connected! Cannot execute query: " .. query)
        return { Execute = function() end }
    end

    local preparedQuery = query

    if args and #args > 0 then
        for i, arg in gp(args) do
            local argType = gt(arg)
            local formattedArg = ""

            if argType == "string" and not gn(arg) then
                formattedArg = SQLObject:escape(arg)
                if not noQuote then
                    formattedArg = "'" .. formattedArg .. "'"
                end
            elseif argType == "number" or (argType == "string" and gn(arg)) then
                formattedArg = arg
            else
                formattedArg = gs(arg) or ""
            end
            
            preparedQuery = sg(preparedQuery, "{" .. (i - 1) .. "}", formattedArg)
        end
    end
    
    return {
        Query = preparedQuery,
        Execute = function(self, callback, varArg)
            sqlExecute(self.Query, callback, varArg)
        end
    }
end

-- UI Data calls
function UI:SendToClient(client, uiId, ...)
    NETWORK:StartNetworkMessage(client, "UI", uiId, ...)
end

function UI:SendCallback(handle, data)
    NETWORK:StartNetworkMessage(false, "UI", handle, unpack(data))
end

function UI:AddListener(id, func)
    DATA[id] = func
end

NETWORK:GetNetworkMessage("UI", function(cl, data)
    local id = data[1]
    table.remove(data, 1)

    if DATA[id] then
        DATA[id](cl, data)
    else
        UTIL:Notify(Color(255, 0, 0), "Database", "No listener found for UI ID " .. gs(id))
    end
end)

function MySQL:ProcessQueuedQueries()
    self.queuedQueries = self.queuedQueries or {}

    if #self.queuedQueries == 0 then
        return
    end

    for _, queryData in gp(self.queuedQueries) do
        MySQL:Start(queryData.query, queryData.callback)
    end

    self.queuedQueries = {}
end

-- Start the connection now
function MySQL:Start(query, callback)
    if not SQLObject or SQLObject:status() ~= mysqloo.DATABASE_CONNECTED then
        UTIL:Notify(Color(255, 0, 0), "Database", "Database connection not established")
        return
    end

    local q = SQLObject:query(query)

    function q:onSuccess(data)
        if callback then
            callback(data)
        end
    end

    function q:onError(err)
        UTIL:Notify(Color(255, 0, 0), "Database", "Query error: " .. err)
    end

    q:start()
end

-- Easy '' adds
function MySQL:Escape(str)
    return sqstr(str)
end

SQL:CreateObject()