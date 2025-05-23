﻿local function includeFiles(fileList, serverOnly)
    for _, file in ipairs(fileList) do
        if SERVER then
            AddCSLuaFile(file)
        end
        if not serverOnly or SERVER then
            include(file)
        end
    end
end

local coreFiles = {
    "essential/sh_config.lua",
    "shared.lua",
    "sh_playerclass.lua",
    "essential/sh_movement.lua",
    "essential/sh_network.lua",
    "essential/sh_utilities.lua"
}

includeFiles(coreFiles)

local files = {
    shared = {
        "essential/timer/sh_timer.lua",
        "nonessential/sh_multi_hops.lua",
        "nonessential/sh_paint.lua",
        "nonessential/sh_ssjtop.lua",
        "nonessential/sh_jumpstats.lua",
        "nonessential/sh_fjt.lua",
        "nonessential/sh_edgehelper.lua",
        "nonessential/sh_rampometer.lua",
        "nonessential/sh_unreal.lua"
    },
    movementFixes = {
        "nonessential/movementfixes/sh_rngfix.lua",
        "nonessential/movementfixes/sh_rampfix.lua",
        "nonessential/movementfixes/sh_boosterfix.lua",
        "nonessential/movementfixes/sh_headbugfix.lua"
    },
    clientModules = {
        "userinterface/cl_fonts.lua",
        "userinterface/cl_settings.lua",
        "userinterface/cl_theme.lua",
        "userinterface/cl_themes.lua",
        "userinterface/cl_ui.lua",
        "userinterface/cl_hud.lua",
        "userinterface/cl_uiutilize.lua",
        "userinterface/numbered/ui_mapvote.lua",
        "userinterface/cl_menu.lua",
        "userinterface/cl_voice.lua",
        "essential/cl_network.lua",
        "userinterface/scoreboards/cl_default.lua",
        "userinterface/chatbox/cl_chatbox.lua",
        "userinterface/cl_mapcolor.lua",
        "userinterface/cl_netgraph.lua",
        "essential/zones/cl_zoneeditor.lua",
        "nonessential/admin/cl_admin.lua",
        "nonessential/strafe/cl_strafehud.lua",
        "nonessential/strafe/cl_trainer.lua",
        "nonessential/strafe/cl_showkeys.lua",
        "nonessential/strafe/cl_showspeed.lua",
        "nonessential/strafe/cl_synchronizer.lua",
        "nonessential/cl_soundstopper.lua",
        "nonessential/cl_cheats.lua",
        "nonessential/fpsfixes/cl_fpsfixes.lua",
        "nonessential/fpsfixes/cl_buffthefps.lua",
        "nonessential/showhidden/cl_init.lua",
        "nonessential/showhidden/cl_lang.lua",
        "nonessential/bash/cl_bash.lua"
    },
    fpsFixesShared = {
        "nonessential/fpsfixes/sh_fpsfixes.lua",
    },
    showHiddenShared = {
        "nonessential/showhidden/sh_init.lua",
        "nonessential/showhidden/luabsp.lua"
    },
    serverOnly = {
        "essential/sv_chat.lua",
        "essential/sv_database.lua",
        "sv_playerclass.lua",
        "sv_command.lua",
        "essential/timer/sv_timer.lua",
        "essential/zones/sv_zones.lua",
        "nonessential/sv_rtv.lua",
        "nonessential/admin/sv_admin.lua",
        "nonessential/admin/sv_commands.lua",
        "nonessential/admin/sv_whitelist.lua",
        "nonessential/sv_replay.lua",
        "nonessential/sv_spectator.lua",
        "nonessential/sv_sync.lua",
        "nonessential/sv_ljstats.lua",
        "nonessential/sv_checkpoint.lua",
        "nonessential/sv_segment.lua",
        "nonessential/sv_setspawn.lua",
        "nonessential/showhidden/sv_init.lua",
        "nonessential/showhidden/sh_init.lua",
        "nonessential/movementfixes/sh_tpfix.lua",
        "nonessential/bash/sv_bash.lua",
        "nonessential/bash/sv_config.lua",
        "nonessential/sh_path.lua"
    },
    misc = {
        "nonessential/misc/cl_centerbox.lua",
        "nonessential/misc/cl_perfprinter.lua",
        "nonessential/misc/cl_peakheight.lua",
        "nonessential/misc/cl_boxgraph.lua",
        "nonessential/misc/cl_jumppred.lua"
    }
}

includeFiles(files.shared)
includeFiles(files.movementFixes)
includeFiles(files.fpsFixesShared)
includeFiles(files.showHiddenShared)

if SERVER then
    for _, file in ipairs(files.clientModules) do
        AddCSLuaFile(file)
    end
    for _, file in ipairs(files.misc) do
        AddCSLuaFile(file)
    end
end

if CLIENT then
    includeFiles(files.clientModules)
    includeFiles(files.misc)
end

if SERVER then
    includeFiles(files.serverOnly, true)
end

util.AddNetworkString("MovementData")
util.AddNetworkString("ToggleWeaponPickup")
util.AddNetworkString("SendVersionData")
util.AddNetworkString("SendVersionDataMenu")

-- Cvars
CreateConVar("bhop_version", tostring(BHOP.Version.GM), {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Version number")
CreateConVar("bhop_prediction", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Prediction enabled")
CreateConVar("bhop_remove_dustmotes", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Toggle remove func_dustmotes")

cachedVersionMsg = nil
notifySent = false

local function VersionToNumber(str)
    return tonumber(str:gsub("[^%d%.]", ""), 10) or 0
end

local function FetchVersionData()
    http.Fetch("http://77.93.141.26/latest_version.json?nocache=" .. os.time(),
        function(body)
            local data = util.JSONToTable(body)
            if data and data.version then
                local latestVersion = data.version
                local currentVersion = BHOP.Version.GM or "unknown"
                local date = BHOP.Version.LastUpdated or "unknown"

                local latestNum = VersionToNumber(latestVersion)
                local currentNum = VersionToNumber(currentVersion)

                if currentNum < latestNum then
                    cachedVersionMsg = "Gamemode is outdated! Current: " .. currentVersion .. " | Latest: " .. latestVersion
                    if not notifySent then
                        UTIL:Notify(Color(255, 0, 255), "Gamemode", cachedVersionMsg)
                        notifySent = true
                    end
                elseif currentNum > latestNum then
                    cachedVersionMsg = "Gamemode is newer than latest! Current: " .. currentVersion .. " | Latest: " .. latestVersion
                    if not notifySent then
                        UTIL:Notify(Color(0, 200, 255), "Gamemode", cachedVersionMsg)
                        notifySent = true
                    end
                else
                    cachedVersionMsg = "Gamemode is up-to-date! Version: " .. currentVersion .. " | Date: " .. date
                    if not notifySent then
                        UTIL:Notify(Color(0, 255, 0), "Gamemode", cachedVersionMsg)
                        notifySent = true
                    end
                end
            else
                cachedVersionMsg = "Failed to parse version data."
                if not notifySent then
                    UTIL:Notify(Color(255, 0, 0), "Gamemode", cachedVersionMsg)
                    notifySent = true
                end
            end
        end,
        function(error)
            cachedVersionMsg = "Failed to check for latest version: " .. error
            if not notifySent then
                UTIL:Notify(Color(255, 0, 0), "Gamemode", cachedVersionMsg)
                notifySent = true
            end
        end
    )
end

hook.Add("InitPostEntity", "DelayedFetchVersion", function()
    timer.Simple(2, function()
        FetchVersionData()
    end)
end)

local nextNameChange, IsWhitelisted = 0, true
local hook_Add, lp, Iv, ct, format = hook.Add, LocalPlayer, IsValid, CurTime, string.format

-- Host name updater
local function ChangeName()
    if not BHOP.EnableCycle then
        return
    end

    local whitelistText = IsWhitelisted and "- whitelist" or ""
    local name = table.Random(BHOP.ServerNames)
    local new_hostname = BHOP.ServerName .. " " .. whitelistText .. " | " .. name

    game.ConsoleCommand("hostname \"" .. new_hostname .. "\"\n")

    SetGlobalString("ServerName", new_hostname)
end

hook_Add("Initialize", "BHOP_RandomNameOnLoad", function()
    if BHOP.EnableCycle then
        ChangeName()
    end
end)

timer.Create("HostnameThink", 30, 0, function()
    if BHOP.EnableCycle then
        ChangeName()
    end
end)

local timerName = "MapReloadTimer"
local interval = 4 * 60 * 60

-- Reload map for long hours
local function ReloadMap()
    local currentMap = game.GetMap()
    RunConsoleCommand("changelevel", currentMap)
end
timer.Create(timerName, interval, 0, ReloadMap)

hook_Add("Initialize", "PrintBhopVersion", function()
    UTIL:Notify(Color(255, 0, 255), "Gamemode", "Bhop Gamemode Version: " .. BHOP.Version.GM)
end)

-- Banned users list
function IsPlayerCfgBanned(steamID)
    return BHOP.Banlist[steamID] or false
end

-- Family sharing bans
function GM:PlayerAuthed(ply, steamID, uniqueID)
    if not ply:IsFullyAuthenticated() then
        UTIL:Notify(Color(255, 0, 255), "CheckFamilySharing", format("[Family Sharing] Player %s is not fully authenticated yet.", ply:Nick()))
        return
    end

    local lenderSteamID64 = ply:OwnerSteamID64()

    if lenderSteamID64 ~= ply:SteamID64() then
        local lenderSteamID = util.SteamIDFrom64(lenderSteamID64)
        UTIL:Notify(Color(255, 0, 255), "CheckFamilySharing", format("[Family Sharing] %s | %s is using a family-shared account from %s", ply:Nick(), ply:SteamID(), lenderSteamID))

        if IsPlayerCfgBanned(lenderSteamID) then
            ply:Kick("Your main account is banned.")
        end
    end
end

-- Get players location
local locationCacheFile = "locations.txt"
local function LoadLocationCache()
    if not file.Exists(locationCacheFile, "DATA") then
        return {}
    end

    local data = file.Read(locationCacheFile, "DATA")
    return util.JSONToTable(data) or {}
end

local function SaveLocationCache(cache)
    file.Write(locationCacheFile, util.TableToJSON(cache))
end

local locationCache = LoadLocationCache()

local function FetchCountryFromAPI(ply, sanitizedIP)
    local apiURL = "https://ipapi.co/" .. sanitizedIP .. "/json/"

    HTTP({
        url = apiURL,
        method = "GET",
        success = function(code, body)
            if code == 200 then
                local jsonResponse = util.JSONToTable(body)
                if jsonResponse and jsonResponse.country_name then
                    local countryName = jsonResponse.country_name

                    locationCache[sanitizedIP] = countryName
                    SaveLocationCache(locationCache)

                    ply:SetNWString("country_name", countryName)

                    local connectMessage = Lang:Get("Connect", { ply:Nick(), ply:SteamID(), countryName })
                    BHDATA:Broadcast("Print", { "Server", connectMessage })
                end
            end
        end
    })
end

function UTIL:GetPlayerCountryByIP(ply)
    local ip = ply:IPAddress() or "localhost"
    local sanitizedIP = string.match(ip, "^([%d%.]+)")

    if not sanitizedIP or sanitizedIP == "127.0.0.1" or sanitizedIP == "localhost" then
        ply:SetNWString("country_name", "Local Network")

        local connectMessage = Lang:Get("Connect", { ply:Nick(), ply:SteamID(), "Local Network" })
        BHDATA:Broadcast("Print", { "Server", connectMessage })
        return
    end

    if locationCache[sanitizedIP] then
        local cachedCountry = locationCache[sanitizedIP]
        ply:SetNWString("country_name", cachedCountry)

        local connectMessage = Lang:Get("Connect", { ply:Nick(), ply:SteamID(), cachedCountry })
        BHDATA:Broadcast("Print", { "Server", connectMessage })
    else
        FetchCountryFromAPI(ply, sanitizedIP)
    end
end

local hasLoadedStartup = false
local function Startup()
    TIMER:Boot()
end
hook_Add("Initialize", "Startup", Startup)

local hasLoaded = false
local function LoadEntities()
    TIMER:DBRetry()
end
hook_Add("InitPostEntity", "LoadEntities", LoadEntities)

-- player spawn call
function GM:PlayerSpawn(ply)
    player_manager.SetPlayerClass(ply, "player_bhop")
    self.BaseClass:PlayerSpawn(ply)
    TIMER:Spawn(ply)
end

-- initial spawn call
function GM:PlayerInitialSpawn(ply)
    TIMER:Load(ply)
end

-- Remove hooks
function GM:CanPlayerSuicide() return false end
function GM:PlayerShouldTakeDamage() return false end
function GM:GetFallDamage() return false end
function GM:PlayerCanHearPlayersVoice() return true end
function GM:IsSpawnpointSuitable() return true end
function GM:PlayerSpawnObject() return false end
function GM:GravGunPunt() return false end
function GM:PhysgunPickup() return false end
function GM:PlayerDeathThink(ply) end
function GM:PlayerSetModel() end

-- Testing command
concommand.Add("_imvalid", function(ply, cmd, args)
    if not Iv(ply) then return end

    collectgarbage("collect")
end)

local weaponPickupState = {}
net.Receive("ToggleWeaponPickup", function(len, ply)
    local newState = net.ReadBool()
    weaponPickupState[ply] = newState

    NETWORK:StartNetworkMessageTimer(ply, "Print", {"Timer", "Weapon Pickup is now " .. (newState and "enabled" or "disabled") .. " for you."})
end)

function GM:PlayerCanPickupWeapon(ply, weapon)
    if weaponPickupState[ply] == false then
        return false
    end

    if ply.WeaponStripped or ply:HasWeapon(weapon:GetClass()) or ply:IsBot() then
        return false
    end

    local primaryAmmoType = weapon:GetPrimaryAmmoType()
    local initialAmmo = 420

    timer.Simple(0, function()
        if IsValid(ply) and IsValid(weapon) and ply:GetActiveWeapon() == weapon then
            ply:SetAmmo(initialAmmo, primaryAmmoType)
        end
    end)

    return true
end

-- Remove dustmotes
hook_Add("InitPostEntity", "ToggleDustMotesRemoval", function()
    if GetConVar("bhop_remove_dustmotes"):GetBool() then
        for _, ent in pairs(ents.FindByClass("func_dustmotes")) do
            if IsValid(ent) then
                ent:Remove()
            end
        end

        for _, ent in pairs(ents.FindByClass("ambient_generic")) do
            if IsValid(ent) then
                ent:Remove()
            end
        end
    end
end)

function GM:EntityTakeDamage(ent, dmg)
    if ent:IsPlayer() then 
        dmg:SetDamage(0)
        return true
    end
    return false
end