--[[~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	🔧 Bunny Hop Server Commands 🔧
		by: fibzy (www.steamcommunity.com/id/fibzy_)

		file: sv_commands.lua
		desc: 💬 Handles all server commands for the Bunny Hop gamemode.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~]]

Command = {
    Functions = {},
}

-- Cache
local lp, Iv, ct, hook_Add = LocalPlayer, IsValid, CurTime, hook.Add
local insert, explode, lower, sub = table.insert, string.Explode, string.lower, string.sub

util.AddNetworkString("OpenRanksPage")
util.AddNetworkString("zone_toggle_hud")
util.AddNetworkString("zone_editor_data")

function SendSSJTopToClient(ply)
    if not IsValid(ply) then return end
    if not SSJTOP or table.IsEmpty(SSJTOP) then
        return
    end

    NETWORK:StartNetworkMessage(ply, "SSJTopData", SSJTOP)
end

-- Map brightness
local brightness = "1"
function SetMapBrightness(value)
    local ply, mult
    if value and isstring(value) then
        mult = value
    elseif value and Iv(value) then
        ply = value
    end

    if ply then
        if ply:IsBot() then return end
        ply:ConCommand("bhop_map_brightness " .. brightness)
    elseif mult then
        brightness = mult
        for _, ply in pairs(player.GetHumans()) do
            ply:ConCommand("bhop_map_brightness " .. mult)
        end
    else
        for _, ply in pairs(player.GetHumans()) do
            ply:ConCommand("bhop_map_brightness " .. brightness)
        end
    end
end
hook_Add("PlayerInitialSpawn", "SetMapBrightness", SetMapBrightness)

-- Jump Stats Menu
if SSJ then
    function SSJ:OpenMenuForPlayer(pl, data)
	    UI:SendToClient(pl, "ssj", data)
    end

    function SSJ:InterfaceResponse(pl, data)
        if not pl.SSJ then self:InitializeSSJData(pl) end
        local k = data[1]
        pl.SSJ["Settings"][k] = not pl.SSJ["Settings"][k]
        pl:SetPData("SSJ_Settings", util.TableToJSON(pl.SSJ["Settings"]))
        self:OpenMenuForPlayer(pl, k)
    end
    UI:AddListener("ssj", function(pl, data) SSJ:InterfaceResponse(pl, data) end)

    function SSJ:AddCommand()
        Command:Register({"ssj", "sj", "ssjmenu"}, function(pl)
            if not pl.SSJ then self:InitializeSSJData(pl) end
            self:OpenMenuForPlayer(pl, pl.SSJ["Settings"])
        end)
    end
    hook_Add("Initialize", "AddCommand", function() SSJ:AddCommand() end)
end

function Command:Register(aliases, func, description, syntax)
    for _, alias in ipairs(aliases) do
        self.Functions[alias] = {func, description or "No description available", syntax or "No syntax available"}
    end
end

local commandCooldowns = {}
local cooldownTime = 1

function Command:Trigger(pl, command, text)
    local mainCommand, commandArgs = command, {}
    if string.find(command, " ", 1, true) then
        local splitData = explode(" ", command)
        mainCommand = splitData[1]
        commandArgs.Upper = {}
        for i = 2, #splitData do
            insert(commandArgs, splitData[i])
            insert(commandArgs.Upper, explode(" ", text)[i])
        end
    end

    local func = self.Functions[mainCommand] and self.Functions[mainCommand][1]
    commandArgs.Key = mainCommand

    local sid = pl:SteamID()
    commandCooldowns[sid] = commandCooldowns[sid] or {}

    local lastUsed = commandCooldowns[sid][mainCommand] or 0
    if CurTime() < lastUsed + cooldownTime then
        return
    end

    commandCooldowns[sid][mainCommand] = CurTime()

    if func then
        return func(pl, commandArgs)
    else
        TIMER:Print(pl, "This command doesn't exist.")
        return nil
    end
end

fallbackAngles = fallbackAngles or {}

-- Restart Player
function Command:PerformRestart(pl, currentFOV)
    if pl.Spectating then
        pl:SetTeam(1)
        pl.Spectating = false
        pl:SetNWInt("Spectating", 0)
        pl:UnSpectate()
    end

    fallbackAngles[pl:SteamID()] = pl:EyeAngles()

    --[[if pl.style == TIMER:GetStyleID("Segment") then
        Segment:Reset(pl)
        Segment:Exit(pl)
    end--]]

    if pl:Team() ~= TEAM_SPECTATOR then
        local wep = IsValid(pl:GetActiveWeapon()) and pl:GetActiveWeapon():GetClass() or "weapon_crowbar"
        pl.ReceiveWeapons = not not wep
        pl:Spawn()
        TIMER:ResetTimer(pl)
        pl.ReceiveWeapons = nil

        if wep and pl:HasWeapon(wep) then
            pl:SelectWeapon(wep)
        end

        if pl.WeaponsFlipped then
            TIMER:Print(pl, "Client", {"WeaponFlip", true})
            SendPopupNotification(pl, "Notification", "Weapons have been flipped.", 2)
        end
    else
        TIMER:Print(pl, Lang:Get("SpectateRestart"))
    end

    if currentFOV and IsValid(pl) then
        pl:SetFOV(currentFOV)
    end
end

function Command:Restart(pl)
    self:PerformRestart(pl)
end

-- Reload the map
local AdminList = BHOP.Server.AdminList

concommand.Add("reload_map", function(ply, cmd, args)
    if Iv(ply) and not AdminList[ply:SteamID()] then
        SendPopupNotification(ply, "Notification", "You do not have permission to use this command.", 2)
        return
    end

    if Replay and Replay.Save then
        Replay:Save(true)
    end

    local currentMap = game.GetMap()
    SendPopupNotification(nil, "Notification", "Reloading map: " .. currentMap .. " in 1 second to save data.", 2)

    timer.Simple(1, function()
        game.ConsoleCommand("changelevel " .. currentMap .. "\n")
    end)
end)

-- Nominate
function Command.Nominate(ply, _, varArgs)
    if not varArgs[1] then return end
    if not RTV:MapExists(varArgs[1]) then return NETWORK:StartNetworkMessageTimer(ply, "Print", {"Notification", Lang:Get("MapInavailable", {varArgs[1]})}) end
    if varArgs[1] == game.GetMap() then return NETWORK:StartNetworkMessageTimer(ply, "Print", {"Notification", Lang:Get("NominateOnMap")}) end
    if not RTV:IsAvailable(varArgs[1]) then return NETWORK:StartNetworkMessageTimer(ply, "Print", {"Notification", "Sorry, this map isn't available on the server itself. Please contact an admin!"}) end

    RTV:Nominate(ply, varArgs[1])
end

-- Style commands
function Command.Style(pl, _, varArgs)
    if not varArgs or not varArgs[1] then
        return
    end

    local styleID = tonumber(varArgs[1]) or TIMER:GetStyleID(varArgs[1])
    if styleID == 0 then
        return
    end

    if pl.style == styleID then
        if pl.style == TIMER:GetStyleID("Bonus") then
            return Command:Restart(pl)
        else
            return NETWORK:StartNetworkMessageTimer(pl, "Print", {"Timer", Lang:Get("StyleEqual", {TIMER:TranslateStyle(pl.style)})})
        end
    end

    if pl.style == TIMER:GetStyleID("Segment") and styleID ~= TIMER:GetStyleID("Segment") then
        Segment:Reset(pl)
        Segment:Exit(pl)
    end

    if styleID == TIMER:GetStyleID("Bonus") and not Zones.BonusPoint then
        return NETWORK:StartNetworkMessageTimer(pl, "Print", {"Timer", Lang:Get("styleBonusNone")})
    elseif styleID == TIMER:GetStyleID("Bonus") then
        TIMER:ResetTimer(pl)
    elseif pl.Style == TIMER:GetStyleID("Bonus") then
        TIMER:BonusReset(pl)
    elseif pl:GetNWInt("inPractice", false) then
        pl.time = nil
        NETWORK:StartNetworkMessageTimer(pl, "Timer", {"Start", pl.time})
    end

    TIMER:LoadStyle(pl, styleID)
    pl.style = styleID
end

-- Goto spectator
local function ToggleSpectate(pl, cmd, args)
    local targetPlayerID = args[1]
    
    if pl.Spectating then
        local target = pl:GetObserverTarget()
        Command:PerformRestart(pl)

        pl.Spectating = false
        pl:SetNWInt("Spectating", 0)
        Spectator:End(pl, target)
    else
        pl:SetNWInt("Spectating", 1)
        pl.Spectating = true
        TIMER:ResetTimer(pl)
        GAMEMODE:PlayerSpawnAsSpectator(pl)

        if targetPlayerID then
            Spectator:NewById(pl, targetPlayerID)
        else
            Spectator:New(pl)
        end
    end
end
concommand.Add("spectate", ToggleSpectate)

-- Remove weapons
concommand.Add("drop", function(pl)
    if not Iv(pl) then return end

    if not pl.Spectating and not pl:IsBot() then
        pl:StripWeapons()
    else
        NETWORK:StartNetworkMessageTimer(pl, "Print", {"Notification", Lang:Get("SpectateWeapon")})
    end
end)

-- Style UI Clicker
local styleIDs = {
    [1] = TIMER:GetStyleID("Normal"),
    [2] = TIMER:GetStyleID("Sideways"),
    [3] = TIMER:GetStyleID("HSW"),
    [4] = TIMER:GetStyleID("W"),
    [5] = TIMER:GetStyleID("A"),
    [6] = TIMER:GetStyleID("L"),
    [7] = TIMER:GetStyleID("E"),
    [8] = TIMER:GetStyleID("Unreal"),
    [9] = TIMER:GetStyleID("Swift"),
    [10] = TIMER:GetStyleID("Bonus"),
    [11] = TIMER:GetStyleID("WTF"),
    [12] = TIMER:GetStyleID("LG"),
    [13] = TIMER:GetStyleID("Backwards"),
    [14] = TIMER:GetStyleID("Stamina"),
    [15] = TIMER:GetStyleID("Segment"),
    [16] = TIMER:GetStyleID("AS"),
    [17] = TIMER:GetStyleID("MM"),
    [18] = TIMER:GetStyleID("HG"),
    [19] = TIMER:GetStyleID("SPEED"),
    [20] = TIMER:GetStyleID("Prespeed")
}

UI:AddListener("style", function(client, data)
    local selectedStyleKey = tonumber(data[1])
    if not selectedStyleKey then return end

    local styleID = styleIDs[selectedStyleKey]
    if styleID then
        Command.Style(client, nil, {styleID})
    else
        NETWORK:StartNetworkMessageTimer(client, "Print", {"Timer", "Invalid style selected."})
        SendPopupNotification(client, "Notification", "Invalid style selected.", 2)
    end
end)

-- FoV changer
function GiveWeaponWithFOV(pl, weaponClass)
    local currentFOV = pl:GetFOV()

    if pl.Spectating or pl:Team() == TEAM_SPECTATOR then
        NETWORK:StartNetworkMessageTimer(pl, "Print", {"Notification", Lang:Get("SpectateWeapon")})
    else
        local bFound = false
        for _, ent in pairs(pl:GetWeapons()) do
            if ent:GetClass() == "weapon_" .. weaponClass then
                bFound = true
                break
            end
        end

        if not bFound then
            pl.WeaponPickup = true
            pl:Give("weapon_" .. weaponClass)
            pl:SelectWeapon("weapon_" .. weaponClass)
            pl.WeaponPickup = nil

            NETWORK:StartNetworkMessageTimer(pl, "Print", {"Notification", Lang:Get("PlayerGunObtain", {weaponClass})})
            SendPopupNotification(pl, "Notification", "You have got a new weapon.", 2)
        else
            NETWORK:StartNetworkMessageTimer(pl, "Print", {"Notification", Lang:Get("PlayerGunFound", {weaponClass})})
        end

        if Iv(pl) then
            pl:SetFOV(currentFOV)
        end
    end
end

-- Listed all commands
function Command:Init()
    local commands = {
        {
            {"changelevel"},
            function(pl, args)
                if not pl:IsAdmin() or not args[1] then
                    TIMER:Print(pl, Lang:Get("MapChangeSyntax"))
                    return
                end

                local targetMap = args[1]
                if not string.find(targetMap, "bhop_") then
                    targetMap = "bhop_" .. targetMap
                end

                if Replay and Replay.Save then
                    Replay:Save(true)
                end

                SendPopupNotification(nil, "Notification", "Changing map to: " .. targetMap .. " in 1 second to save data.", 2)

                game.ConsoleCommand("changelevel " .. targetMap .. "\n")
            end,
            "Change the current map to the specified map (Admin only)",
            "<mapname>"
        },

        -- Admin Menu
        {
            {"admin"},
            function(pl, args)
                if Admin and Admin.CommandProcess then
                    Admin.CommandProcess(pl, args)
                else
                    TIMER:Print(pl, "Admin is not installed or is missing.")
                end
            end,
            "Admin command",
            "<arguments>"
        },

        -- Zone Menu
        {
            {"editzone", "zedit", "zone", "zonelist", "zones"},
            function(pl, args)
                if not Admin:CanAccess(pl, Admin.Level.Zoner) then
                    return BHDATA:Send(pl, "Print", {"Admin", "You don't have access to use this command!"})
                end

net.Start("zone_menu_types")
net.WriteUInt(table.Count(Zones.Type), 8)
for name, id in pairs(Zones.Type) do
    net.WriteString(name)
    net.WriteUInt(id, 8)
end
net.Send(pl)

-- Tell client to show HUD
net.Start("zone_toggle_hud")
net.WriteBool(true)
net.Send(pl)

-- Tell client to activate editor
net.Start("zone_editor_data")
net.WriteBool(true) -- active
net.WriteUInt(0, 8) -- default type ID (or whatever you want)
net.Send(pl)

            end,
            "Zone command",
            "<arguments>"
        },

        -- Profie Stats
        {
            {"profile", "userstats"},
            function(pl, args)
                if not IsValid(pl) then return end

                if not args or #args < 1 then
                    TIMER:Print(pl, "Usage: !profile <player name>")
                    return
                end

                local nameQuery = table.concat(args, " "):Trim():lower()
                if nameQuery == "" then
                    TIMER:Print(pl, "Please provide a valid player name.")
                    return
                end

                -- Find target player
                local target
                for _, v in ipairs(player.GetHumans()) do
                    if v:Nick():lower():find(nameQuery, 1, true) then
                        target = v
                        break
                    end
                end

                if not IsValid(target) then
                    TIMER:Print(pl, "Could not find that player.")
                    return
                end

                TIMER:SendProfileData(pl, target)
            end,
            "Views stats for a player",
            "<style> [page]"
        },

        -- Set Tier
        {
            {"settier", "tierset"},
            function(pl, args)
                local tier = tonumber(args[1])
                Admin:SetMapTier(pl, tier)
            end,
            "Sets tier",
            "<style> [page]"
        },

        -- Themes Menu
        {
            {"theme", "themeeditor", "themes"},
            function(pl)
                pl:ConCommand("bhop_thememanager")
            end,
            "Opens the theme manager",
            "[subcommand]"
        },

        -- Restart
        {
        {"restart", "r", "respawn"},
        function(pl)
            local currentFOV = pl.GetFOV and pl:GetFOV() or nil
            self:PerformRestart(pl, currentFOV)
            SendPopupNotification(pl, "Notification", "Your timer has been restarted.", 2)
        end,
        "Restart or respawn the player",
        "[subcommand]"
        },

        -- JHUD Menu
        {
            {"jhud", "jumphud"},
            function(pl, args)
                if not IsValid(pl) then return end
                NETWORK:StartNetworkMessage(pl, "OpenJHUDMenu")
            end,
            "Jhud Menu command",
            "<arguments>"
        },

        -- Strafe Trainer Menu
        {
            {"strafetrainer", "strafetrainermenu"},
            function(pl, args)
                if not IsValid(pl) then return end
                NETWORK:StartNetworkMessage(pl, "OpenStrafeTrainerMenu")
                TIMER:Print(pl, "Strafe Trainer Menu has been opened!")
            end,
            "Paint Menu command",
            "<arguments>"
        },

        -- Paint Menu
        {
            {"paint", "paintmenu"},
            function(pl, args)
                if not IsValid(pl) then return end
                NETWORK:StartNetworkMessage(pl, "OpenPaintMenu")
                TIMER:Print(pl, "Paint Menu has been opened!")
            end,
            "Paint Menu command",
            "<arguments>"
        },

        -- Booster Fix
        {
            {"boosterfix", "bfix"},
            function(pl, args)
                local pFix = pl.Boosterfix
                pFix.Enabled = not pFix.Enabled
                pl:SetPData("BoosterFix", pFix.Enabled and "1" or "0")

                TIMER:Print(pl, "You have " .. (pFix.Enabled and "enabled" or "disabled") .. " Consistent Boosterfix.") 
            end,
            "Booster Fix command",
            "<arguments>"
        },

        -- Show or Hide Players
        {
        {"show", "hide", "showplayers", "hideplayers"},
        function(pl, args)
            local key = args.Key and string.lower(args.Key) or ""

            if string.sub(key, 1, 4) == "show" then
                NETWORK:StartNetworkMessage(pl, "TogglePlayerVisibility", true)
                TIMER:Print(pl, "Players Enabled. You can now see players!")
            elseif string.sub(key, 1, 4) == "hide" then
                NETWORK:StartNetworkMessage(pl, "TogglePlayerVisibility", false)
                TIMER:Print(pl, "Players Disabled. Players are now hidden!")
            else
                TIMER:Print(pl, "Invalid command. Use show/hide")
            end
        end,
        "Hide or show players",
        "[subcommand]"
        },

        -- Water Command
        {
        { "water", "fixwater", "reflection", "refraction" },
        function(pl, args)
            NETWORK:StartNetworkMessage(pl, "ToggleWaterFX")
        end,
        "Hide or show water",
        "[subcommand]"
        },

        -- Spectate
        {
            {"spectate", "spec", "watch", "view"},
            function(pl, _, varArgs)
                varArgs = varArgs or {}

                if pl.Spectating and varArgs[1] then
                    Spectator:NewById(pl, varArgs[1], true, varArgs[2])
                elseif pl.Spectating then
                    local target = pl:GetObserverTarget()
                    self:PerformRestart(pl)
                    pl.Spectating = false
                    pl:SetNWInt("Spectating", 0)
                    Spectator:End(pl, target)
                else
                    pl:SetNWInt("Spectating", 1)
                    pl.Spectating = true
                    TIMER:ResetTimer(pl)
                    GAMEMODE:PlayerSpawnAsSpectator(pl)
                    if varArgs[1] then
                        Spectator:NewById(pl, varArgs[1], nil, varArgs[2])
                    else
                        Spectator:New(pl)
                    end
                end
            end,
            "Toggle spectate mode or spectate a specific player",
            "[playerID]"
        },

        -- Noclip
        {
            {"noclip", "freeroam", "clip", "wallhack"},
            function(pl, _, varArgs)
                if not pl:GetNWInt("inPractice") and (pl.timeTick or pl.bonustimeTick) then
                    TIMER:Print(pl, "Your timer has been stopped due to the use of Noclip.")
                    SendPopupNotification(pl, "Notification", "Your timer has been stopped due to the use of Noclip.", 2)

                    pl:StopAnyTimer()
                    pl:SetNWInt("inPractice", true)
                    pl:ConCommand("noclip")
                elseif not pl:GetNWInt("inPractice") then
                    TIMER:Print(pl, "You cannot use Noclip in the Start Zone.")
                    return
                end
                pl:ConCommand("noclip")
            end,
            "Toggle noclip mode",
            "[subcommand]"
        },

        -- Showtriggers
        {
            {"showtriggers", "st", "maptriggers"},
            function(pl, _, varArgs)
                local currentValue = pl:GetInfoNum("showtriggers_enabled", 0)

                if currentValue == 0 then
                    pl:ConCommand("showtriggers_enabled 1")
                    TIMER:Print(pl, "ShowTriggers Enabled. You can now see triggers.")
                else
                    pl:ConCommand("showtriggers_enabled 0")
                    TIMER:Print(pl, "ShowTriggers Disabled. Triggers are now hidden.")
                end
            end,
            "Toggle triggers",
            "[subcommand]"
        },

        -- Showclips
        {
            {"showclips", "clips", "mapclips"},
            function(pl, _, varArgs)
                local currentValue = pl:GetInfoNum("showclips", 0)

                if currentValue == 0 then
                    pl:ConCommand("showclips 1")
                    TIMER:Print(pl, "ShowClips Enabled. You can now see clips.")
                else
                    pl:ConCommand("showclips 0")
                    TIMER:Print(pl, "ShowClips Disabled. clips are now hidden.")
                end
            end,
            "Toggle triggers",
            "[subcommand]"
        },

        -- Goto Player
        {
            {"tp", "tpto", "goto", "teleport", "tele"},
            function(pl, args)
                if not pl:GetNWInt("inPractice", false) then
                    TIMER:Print(pl, "You must disable your timer, use noclip, or enable checkpoints to allow teleportation first.")
                    return
                end

                if #args > 0 then
                    local searchTerm = string.lower(args[1])
                    for _, p in pairs(player.GetAll()) do
                        if string.find(string.lower(p:Name()), searchTerm, 1, true) then
                            pl:SetPos(p:GetPos())
                            pl:SetEyeAngles(p:EyeAngles())
                            pl:SetLocalVelocity(Vector(0, 0, 0))
                            TIMER:Print(pl, "You have been teleported to " .. p:Name())
                            return
                        end
                    end
                    TIMER:Print(pl, "Could not find a valid player with search terms: " .. args[1])
                else
                    TIMER:Print(pl, "Could not find a valid player with search terms")
                end
            end,
            "Teleport to a player",
            "<playername>"
        },

        -- Goto Start
        {
            {"start", "gostart", "gotostart", "tpstat"},
            function(pl, args)
                if not pl:GetNWInt("inPractice", false) then
                    pl.outsideSpawn = true
                    TIMER:Disable(pl)
                end

                local vPoint = Zones:GetCenterPoint(Zones.Type["Normal Start"])
                if vPoint then
                    pl:SetPos(vPoint)
                    BHDATA:Send(pl, "Print", { "Timer", Lang:Get("PlayerTeleport", { "the normal start zone" }) })
                    SendPopupNotification(pl, "Notification", "Teleported to the normal start zone.", 2)
                else
                    BHDATA:Send(pl, "Print", { "Timer", Lang:Get("MiscZoneNotFound", { "normal start" }) })
                end
            end,
            "Go to end zone",
            "[subcommand]"
        },

        -- Goto End
        {
            {"end", "goend", "gotoend", "tpend"},
            function(pl, args)
                if not pl:GetNWInt("inPractice", false) then
                    pl.outsideSpawn = true
                    TIMER:Disable(pl)
                end

                local vPoint = Zones:GetCenterPoint(Zones.Type["Normal End"])
                if vPoint then
                    pl:SetPos(vPoint)

                    BHDATA:Send(pl, "Print", { "Timer", Lang:Get("PlayerTeleport", { "the normal end zone" }) })
                    SendPopupNotification(pl, "Notification", "Teleported to the normal end zone.", 2)
                else
                    BHDATA:Send(pl, "Print", { "Timer", Lang:Get("MiscZoneNotFound", { "normal end" }) })
                end
            end,
            "Go to end zone",
            "[subcommand]"
        },

        -- Goto Bonus Start
        {
            {"bonusstart", "gobstart", "gotobonusstart", "tpbonustart"},
            function(pl, args)
                if not pl:GetNWInt("inPractice", false) then
                    pl.outsideSpawn = true
                    TIMER:Disable(pl)
                end

                local vPoint = Zones:GetCenterPoint(Zones.Type["Bonus Start"])
                if vPoint then
                    pl:SetPos(vPoint)
                    BHDATA:Send(pl, "Print", { "Timer", Lang:Get("PlayerTeleport", { "the bonus start zone" }) })
                    SendPopupNotification(pl, "Notification", "Teleported to the bonus start zone.", 2)
                else
                    BHDATA:Send(pl, "Print", { "Timer", Lang:Get("MiscZoneNotFound", { "bonus start" }) })
                end
            end,
            "Go to end zone",
            "[subcommand]"
        },

        -- Goto Bonus End
        {
            {"bonusend", "gobend", "gotobend", "tptobend", "bend"},
            function(pl, args)
                if not pl:GetNWInt("inPractice", false) then
                    pl.outsideSpawn = true
                    TIMER:Disable(pl)
                end

                local vPoint = Zones:GetCenterPoint(Zones.Type["Bonus End"])
                if vPoint then
                    pl:SetPos(vPoint)
                    BHDATA:Send(pl, "Print", { "Timer", Lang:Get("PlayerTeleport", { "the bonus end zone" }) })
                    SendPopupNotification(pl, "Notification", "Teleported to the bonus end zone.", 2)
                else
                    BHDATA:Send(pl, "Print", { "Timer", Lang:Get("MiscZoneNotFound", { "bonus end" }) })
                end
            end,
            "Go to end zone",
            "[subcommand]"
        },

        -- RTV
        {
            {"rtv", "vote", "votemap"},
            function(pl, args)
                if #args > 0 then
                    local subcmd = string.lower(args[1])
                    if (subcmd == "who" or subcmd == "list") and RTV and RTV.Who then
                        RTV:Who(pl)
                    elseif (subcmd == "check" or subcmd == "left") and RTV and RTV.Check then
                        RTV:Check(pl)
                    elseif subcmd == "revoke" and RTV and RTV.Revoke then
                        RTV:Revoke(pl)
                    elseif subcmd == "extend" and Admin and Admin.VIPProcess then
                        Admin.VIPProcess(pl, {"extend"})
                    else
                        TIMER:Print(pl, subcmd .. " is an invalid subcommand for rtv. Valid: who, list, check, left, revoke, extend")
                    end
                else
                    if RTV and RTV.Vote then
                        RTV:Vote(pl)
                    else
                        TIMER:Print(pl, "RTV system is not installed.")
                    end
                end
            end,
            "Rock the vote commands",
            "[subcommand]"
        },

        -- Revoke RTV
        {
            {"revoke"},
            function(pl, args)
                RTV:Revoke(pl)
            end,
            "Revoke Rock the vote",
            "[subcommand]"
        },

        -- Revote
        {
            {"revote", "openrtv"},
            function(pl, args)
                if not RTV.VotePossible then
                    TIMER:Print(pl, "There is no active vote.")
                else
                    local RTVSend = {}
                    for _, map in pairs(RTV.Selections) do
                        table.insert(RTVSend, RTV:GetMapData(map))
                    end
			        UI:SendToClient(false, "rtv", "Revote", RTVSend)
			        UI:SendToClient(false, "rtv", "VoteList", RTV.MapVoteList)
                end
            end,
            "Re-open the RTV voting menu",
            "[subcommand]"
        },

        -- Time Left
        {
            {"timeleft", "time", "remaining"},
            function(pl)
                TIMER:Print(pl, Lang:Get("TimeLeft", {TIMER:Convert(RTV.MapEnd - CurTime())}))
            end,
            "Displays the time left for the current map",
            ""
        },

        -- Show HUD
        {
            {"showgui", "showhud", "hidegui", "hidehud", "togglegui", "togglehud"},
            function(pl, args)
                TIMER:Print(pl, "Client", {"GUIVisibility", string.sub(args.Key, 1, 4) == "hide" and 0 or (string.sub(args.Key, 1, 4) == "show" and 1 or -1)})
            end,
            "Toggle GUI visibility",
            ""
        },

        -- Nominate
        {
            {"nominate", "rtvmap", "playmap", "maps"},
           function(pl, args)
                if args[1] then
                    Command.Nominate(pl, nil, args)
                else
                    UI:SendToClient(pl, "nominate", {RTV.MapListVersion})
                end
            end,
            "Nominate a map for the next round",
            "[mapname]"
        },


        -- WR List via F1 Menu
        {
            {"wr", "wrlist", "records"},
            function(pl, args)
                net.Start("OpenWorldRecords")
                net.Send(pl)
            end,
            "Displays world records or record list",
            "<style> [page]"
        },


        -- Rank via F1 Menu
        {
            {"rank", "ranks", "ranklist"},
            function(pl, args)
                net.Start("OpenRanksPage")
                net.Send(pl)
            end,
            "Displays world records or record list",
            "<style> [page]"
        },

        -- WR List Old Numbered UI
        --[[{
            {"wr", "wrlist", "records"},
            function(pl, args)
                local stylename, page = pl.style, 1
                if #args > 0 then
                    TIMER:SendRemoteWRList(pl, args[1], stylename, page)
                else
                    TIMER:GetRecordList(stylename, page, function(wrList)
                        UI:SendToClient(pl, "wr", wrList, stylename, page, TIMER:GetRecordCount(stylename))
                    end)
                end
            end,
            "Displays world records or record list",
            "<style> [page]"
        },--]]

        -- Top Players List
        {
            {"top", "topplayers"},
            function(pl, args)
                local styleArg = args[1] or "normal"
                local page = tonumber(args[2]) or 1

                local styleID = TIMER:GetStyleID(styleArg)
                if not styleID then return end

                TIMER:SendTopList(pl, page, styleID)
            end,
            "Displays top players list",
            "<style> [page]"
        },

        -- Maps Beat List
        {
            {"beat", "mapsbeat"},
            function(pl, args)
                local styleArg = args[1] or "normal"

                local styleID = TIMER:GetStyleID(styleArg)
                if not styleID then return end

                pl.style = styleID

                TIMER:GetMapsBeat(pl, styleID)
            end,
            "Displays maps beat list",
            "<style> [page]"
        },

        -- Discord Command
        {
            {"discord", "opendiscord"},
            function(pl, args)
                NETWORK:StartNetworkMessage(pl, "OpenDiscord")
            end,
            "Opens the Discord link.",
            ""
        },

        -- Tutorial Command
        {
            {"tut", "tutorial"},
            function(pl, args)
                NETWORK:StartNetworkMessage(pl, "OpenTutorial")
            end,
            "Opens the tutorial link.",
            ""
        },

        -- Normal WR
        --[[{
            {"nwr", "normalwr", "wrnormal"},
            function(pl, args)
                local style, page = TIMER:GetStyleID("N"), 1
                if #args > 0 then
                    TIMER:SendRemoteWRList(pl, args[1], style, page)
                else
                    TIMER:GetRecordList(style, page, function(records)
                        UI:SendToClient(pl, "wr", records, style, page, TIMER:GetRecordCount(style))
                    end)
                end
            end,

            "Displays normal world records or record list",
            "<style> [page]"
        },--]]

        -- Style WR Num UI
        --[[{
            {"wr", "records", "worldrecords"},
            function(pl, args)
            local styleAliases = {
                ["n"] = "N",
                ["sw"] = "SW",
                ["hsw"] = "HSW",
                ["w"] = "W",
                ["lg"] = "LG",
                ["bonus"] = "Bonus",
                ["stamina"] = "Stamina" }

                local styleArg = args[1] and args[1]:lower() or "n"
                local styleName = styleAliases[styleArg] or "N"
                local styleID = TIMER:GetStyleID(styleName)
                local page = tonumber(args[2]) or 1

                TIMER:GetRecordList(styleID, page, function(records)
                    UI:SendToClient(pl, "wr", records, styleID, page, TIMER:GetRecordCount(styleID))
                end)
            end,

            "Displays normal world records or record list",
            "<style> [page]"
        },--]]

        -- Style Menu
        {
            {"style", "mode", "bhop", "styles", "modes"},
            function(pl)
                UI:SendToClient(pl, "style", {})
            end,
            "Opens the style selection menu",
            ""
        },

        -- Main Menu
        {
            {"menu", "options", "mainmenu"},
            function(pl)
                UI:SendToClient(pl, "menu", {})
            end,
            "Opens the main bhop menu",
            "[subcommand]"
        },

        -- Segment
        {
            {"segment", "segmented", "tas", "seg"},
            function(pl)
                if (pl.style ~= TIMER:GetStyleID("Segment")) then
                    Command.Style(pl, nil, { TIMER:GetStyleID("Segment")})
                    BHDATA:Send(pl, "Print", {"Timer", "To reopen the segment menu at any time, use this command again."})
                    SendPopupNotification(pl, "Notification", "To reopen the segment menu at any time, use this command again.", 2)
                end

                UI:SendToClient(pl, "segment")
            end,
            "Activate segmented mode and open the segment menu",
            "[subcommand]"
        },

        -- Give weapons
        {
            {"glock", "usp", "knife", "p90", "deagle", "scout", "awp", "crowbar"},
            function(pl, args)
                     GiveWeaponWithFOV(pl, args.Key)
            end,
            "Gives the player a specific weapon",
            "<weapon>"
        },

        -- Remove weapons
        {
            {"g", "remove", "strip", "stripweapons"},
            function(pl)
                if not pl.Spectating and not pl:IsBot() then
                    pl:StripWeapons()
                    SendPopupNotification(pl, "Notification", "Striped your weapons", 2)
                else
                    NETWORK:StartNetworkMessageTimer(pl, "Print", {"Notification", Lang:Get("SpectateWeapon")})
                end
            end,
            "Remove all weapons from the player",
            "[subcommand]"
        },

        -- Save Replay
        {
            {"replaysave", "saverun", "savereplay", "replay save"},
            function(pl)
                if not pl:IsAdmin() then
                    TIMER:Print(pl, "You do not have permission to save replays.")
                    return
                end

                if Replay and Replay.Save then
                    Replay:Save(true)
                end

                TIMER:Print(pl, "Replay has been saved.")
                SendPopupNotification(nil, "Notification", "Replay has been saved!", 2)
            end,
            "Save the current replay data (Admin only)",
            "[subcommand]"
        },

        -- Lines Path Replay
        {
            {"showlines", "showtrail", "trail", "viewtrail", "showtrail", "path"},
            function(pl)
                pl.ReplayLines = pl.ReplayLines or {}
                pl.ReplayLines.Enabled = not pl.ReplayLines.Enabled
                pl:SetPData("replay_beams", pl.ReplayLines.Enabled and "1" or "0")

                if pl.ReplayLines.Enabled then
                    local landings = Replay:GetAllLandings(1)

                    for _, pos in ipairs(landings) do
                        net.Start("ShavitLine_Beam")
                        net.WriteVector(pos - Vector(10, 0, 0))
                        net.WriteVector(pos + Vector(10, 0, 0))
                        net.WriteColor(Color(0, 255, 0))
                        net.Send(pl)
                    end
                end

                if not pl.ReplayLines.Enabled then
                    net.Start("ShavitLine_Clear")
                    net.Send(pl)
                end

                TIMER:Print(pl, "You have " .. (pl.ReplayLines.Enabled and "enabled" or "disabled") .. " Replay Path Lines.")
            end,
            "Show the replay path landings",
            "[subcommand]"
        },

        -- Long Jump
        {
        {"lj", "ljstats"}, 
        function(pl)
            if not pl.ljen then 
                pl.ljen = true
                TIMER:Print(pl, "LJStats Enabled.")
            else
                pl.ljen = false
                TIMER:Print(pl, "LJStats Disabled.")
            end
        end,
        "Enable or disable LJ stats.", 
        "[subcommand]"
        },

        -- SSJTop
        {
         {"ssjtop", "topssj", "speedjump", "leaderboard"},
        function(pl)
            SendSSJTopToClient(pl)
        end,
        "Enable or disable LJ stats.", 
        "[subcommand]"
        },

        -- Wr Sounds
        {
        {"wrsounds", "wrsound"}, 
        function(pl)
            if not IsValid(pl) then return end

            if pl:GetInfoNum("bhop_wrsfx", 0) == 0 then
                pl:ConCommand("bhop_wrsfx 1")
                NETWORK:StartNetworkMessageTimer(pl, "Print", { "Notification", "WR sounds ON :)" })
            else
                pl:ConCommand("bhop_wrsfx 0")
                NETWORK:StartNetworkMessageTimer(pl, "Print", { "Notification", "WR sounds OFF :(" })
            end
        end,
        "Toggle WR sound effects on/off",
        "[subcommand]"
        },

        {
        {"runs", "setrun", "replay", "replayset"},
        function(pl, args)
            local list = Replay:GetMultiBots()

            if not args[1] then
                if #list > 0 then
                    return NETWORK:StartNetworkMessageTimer(pl, "Print", { "Notification", "Runs on these styles are recorded and playable: " .. string.Implode(", ", list) .. " (Use !replay Style to start a playback.)" })
                else
                    return NETWORK:StartNetworkMessageTimer(pl, "Print", { "Notification", "There are no other replays available for playback." })
                end
            end

            local style = tonumber(args[1])
            if not style then
                local stylename = string.Implode(" ", args):lower()
                stylename = string.Trim(stylename)
    
                local styleID = nil

                for id, _ in pairs(TIMER.Styles) do
                    if string.lower(TIMER:StyleName(id)) == stylename then
                        styleID = id
                        break
                    end
                end

                if not styleID or not TIMER:IsValidStyle(styleID) then
                    return NETWORK:StartNetworkMessageTimer(pl, "Print", { "Notification", "You have entered an invalid style name. Use the exact name shown on !styles or use their ID." })
                end

                style = styleID
            end

            local Change = Replay:ChangeMultiBot(style)
            if string.len(Change) > 10 then
                NETWORK:StartNetworkMessageTimer(pl, "Print", { "Notification", Change })
            else
                NETWORK:StartNetworkMessageTimer(pl, "Print", { "Notification", Lang:Get("BotMulti" .. Change) })
            end
        end,
        "Replay commands",
        "[subcommand]"
        },

        -- Map/Points/tier
        {
            {"map", "points", "tier"}, 
            function(pl, args)
                local mapName = args[1] or game.GetMap()
                local tier = 1
                local wr = TIMER:GetMapWRTime(mapName, pl.style) or 0
                local record = pl.record or 0
                local completions = TIMER:GetMapCompletionCount(mapName, pl.style, pl)

                if RTV:MapExists(mapName) then
                    local mapData = RTV:GetMapData(mapName)
                    tier = mapData[4] or 1
                end

                local points = TIMER:CalculateJustasPoints(record, wr, tier, completions)
                local displaypts = "You earned " .. points .. " Points on this map - Tier " .. tier .. ""

                BHDATA:Send(pl, "Print", {
                    "Notification",
                    Lang:Get("MapInfo", {
                        mapName,
                        "Tier " .. tier,
                        displaypts,
                        ""
                    })
                })
            end,
            "Toggle WR sound effects on/off",
            "[subcommand]"
        },

        -- Kick
       {
            {"kick", "kicplayer"},
            function(pl, args)
                if not IsValid(pl) or not pl:IsAdmin() then
                    if IsValid(pl) then TIMER:Print(pl, "You do not have permission to use this command.") end
                    return
                end

                if #args < 1 then
                    TIMER:Print(pl, "Usage: !kick <SteamID/Name> [reason]")
                    return
                end

                local target = args[1]
                local reason = table.concat(args, " ", 2) or "No reason provided"
                local targetPlayer = nil

                for _, ply in ipairs(player.GetAll()) do
                    if string.find(string.lower(ply:Nick()), string.lower(target), 1, true) then
                        targetPlayer = ply
                        break
                    end
                end

                if not IsValid(targetPlayer) and string.match(target, "^STEAM_[0-5]:[01]:%d+$") then
                    for _, ply in ipairs(player.GetAll()) do
                        if ply:SteamID() == target then
                            targetPlayer = ply
                            break
                        end
                    end
                end

                if IsValid(targetPlayer) then
                    targetPlayer:Kick("Kicked by Admin: " .. reason)
        
                    if UTIL and UTIL.Notify then
                        UTIL:Notify(Color(255, 0, 0), "BanSystem", "Player " .. targetPlayer:Nick() .. " has been kicked. Reason: " .. reason)
                    end
                else
                    TIMER:Print(pl, "Player not found.")
                end
            end,
            "Kick player",
            "[subcommand]"
        },
    }

    for _, cmd in ipairs(commands) do
        self:Register(unpack(cmd))
    end

    for id, styleData in ipairs(TIMER.Styles) do
        local aliases = styleData[3]

        self:Register(aliases, function(pl)
            Command.Style(pl, nil, {tostring(id)})
        end, "Switch to style: " .. styleData[1], "<styleID>")
    end
end

UI:AddListener("nominate", function(client, data)
    local mapName = data[1]
    if mapName then
        Command.Nominate(client, nil, {mapName})
    end
end)

-- Player Say
GaggedPlayers = GaggedPlayers or {}

function GM:PlayerSay(pl, text, team)
    local command = lower(text:Trim())

    if GaggedPlayers and GaggedPlayers[pl:SteamID()] then
        NETWORK:StartNetworkMessageTimer(pl, "Print", { "Notification", "You been gagged!" })
        return ""
    end

    if command == "rtv" then
        if RTV and RTV.Vote then
            RTV:Vote(pl)
        else
            NETWORK:StartNetworkMessageTimer(pl, "Print", { "Notification", "RTV system is not installed." })
        end
        return ""
    end

    local prefix = sub(command, 1, 1)
    if prefix == "!" or prefix == "/" then
        local commandStripped = lower(sub(command, 2))

        if Command and Command.Trigger then
            local reply = Command:Trigger(pl, commandStripped, text)
            return type(reply) == "string" and reply or ""
        end
    end

    if Admin and Admin.HandleTeamChat then
        return not team and text or Admin:HandleTeamChat(pl, text, text)
    end

    return text
end

-- UI spectate
NETWORK:GetNetworkMessage("ToggleSpectateMode", function(client, data)
    local targetPlayerID = data[1]

    if client.Spectating then
        local target = client:GetObserverTarget()
        Command:PerformRestart(client)
        client.Spectating = false
        client:SetNWInt("Spectating", 0)
        Spectator:End(client, target)
    else
        client:SetNWInt("Spectating", 1)
        client.Spectating = true
        TIMER:ResetTimer(client)

        GAMEMODE:PlayerSpawnAsSpectator(client)

        if targetPlayerID then
            Spectator:NewById(client, targetPlayerID)
        else
            Spectator:New(client)
        end
    end
end)

-- Clickers
util.AddNetworkString("OpenBhopMenu")
util.AddNetworkString("OpenWorldRecords")
util.AddNetworkString("OpenWorldRecords")

-- F1
function GM:ShowHelp(pl)
    net.Start("OpenBhopMenu")
    net.Send(pl)
end

-- F2
function GM:ShowTeam(pl)
    NETWORK:StartNetworkMessage(pl, "OpenSpectateDialog", {})
end

-- F3
hook.Add("ShowSpare1", "OpenWRMenuF4", function(ply)
    if not IsValid(ply) then return end
    net.Start("OpenWorldRecords")
    net.Send(ply)
end)

Command:Init()