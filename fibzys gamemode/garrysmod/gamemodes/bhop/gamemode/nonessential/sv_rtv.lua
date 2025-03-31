﻿RTV = RTV or {
    Initialized = 0, VotePossible = false,
    DefaultExtend = 15, MaxSlots = 64,
    Extends = 0, Nominations = {},
    LatestList = {}, MapLength = 90 * 60,
    MapInit = CurTime(), MapEnd = 0,
    MapVotes = 0,
    MapVoteList = {0, 0, 0, 0, 0, 0, 0},
    MapListVersion = 1,
    Timers = {}
}

local MapList = MapList or {}
local hook_Add = hook.Add

util.AddNetworkString("SendRTVTimeLeft")

local lastTimeLeft = -1

function RTV:SendTimeLeft()
    if not RTV.MapEnd or not RTV.VotePossible then return end

    local timeLeft = math.max(0, RTV.MapEnd - CurTime()) 

    if timeLeft ~= lastTimeLeft then
        lastTimeLeft = timeLeft
        net.Start("SendRTVTimeLeft")
        net.WriteFloat(timeLeft)
        net.Broadcast()
    end
end

local broadcastInterval = 10
timer.Create("BroadcastRTVTimeLeft", broadcastInterval, 0, function()
    if RTV.VotePossible then
        RTV:SendTimeLeft()
    else
        timer.Remove("BroadcastRTVTimeLeft")
    end
end)

function RTV:Init()
    RTV.MapInit = CurTime()
    RTV.MapEnd = RTV.MapInit + RTV.MapLength

    RTV:LoadData()
    RTV:TrueRandom(1, 5)

    timer.Create("RTV_MapCountdown", RTV.MapLength, 1, function() RTV:StartVote() end)
    timer.Create("BroadcastRTVTimeLeft", BHOP.RTV.ChangeMapTime, 0, function() RTV:SendTimeLeft() end)
end

function RTV:CreateTimer(name, delay, func)
    RTV.Timers[name] = {endTime = CurTime() + delay, callback = func}
end

function RTV:StartVote()
    if RTV.VotePossible then return end

    RTV.VotePossible = true
    RTV.Selections = {}
    BHDATA:Broadcast("Print", {"Server", Lang:Get("VoteStart")})
    SendPopupNotification(nil, "Notification", "Choose your maps!", BHOP.RTV.ChangeMapTime)

    local RTVTempList = {}
    for map, voters in pairs(RTV.Nominations) do
        local nCount = #voters
        RTVTempList[nCount] = RTVTempList[nCount] or {}
        table.insert(RTVTempList[nCount], map)
    end

    local Added = 0
    for i = RTV.MaxSlots, 1, -1 do
        if RTVTempList[i] then
            for _, map in ipairs(RTVTempList[i]) do
                if Added >= 5 then break end
                table.insert(RTV.Selections, map)
                Added = Added + 1
            end
        end
    end

    if Added < 5 and #MapList > 0 then
        local indices = {}
        for i = 1, #MapList do
            table.insert(indices, i)
        end
    
        for i = #indices, 2, -1 do
            local j = math.random(i)
            indices[i], indices[j] = indices[j], indices[i]
        end
    
        for _, index in ipairs(indices) do
            if Added >= 5 then break end
            local data = MapList[index]
            if (data[2] or 0) > 0 and not table.HasValue(RTV.Selections, data[1]) and data[1] ~= game.GetMap() then
                table.insert(RTV.Selections, data[1])
                Added = Added + 1
            end
        end
    end

    local RTVSend = {}
    for _, map in ipairs(RTV.Selections) do
        table.insert(RTVSend, RTV:GetMapData(map))
    end

    UI:SendToClient(false, "MapVote", "started", RTVSend)
    RTV:CreateTimer("EndVote", 15, function() if not RTV.VIPTriggered then RTV:EndVote() end end)

    RTV:CreateTimer("InstantVote", 0.1, function()
        for map, voters in pairs(RTV.Nominations) do
            for id, data in ipairs(RTVSend) do
                if data[1] == map then
                    UI:SendToClient(voters, "MapVote", "instant", id)
                end
            end
        end
    end)
end

function RTV:EndVote()
    RTV.VIPTriggered = nil

    if RTV.CancelVote then
        RTV.VotePossible = false
        return RTV:ResetVote("Yes", 2, false, "VoteCancelled")
    end

    local max, won = 0, -1
    for i = 1, 7 do
        if RTV.MapVoteList[i] > max then
            max = RTV.MapVoteList[i]
            won = i
        end
    end

    if max == 0 then
        won = 6
    end

    if won <= 0 then
        won = RTV:TrueRandom(1, 5)
    elseif won == 6 then
        BHDATA:Broadcast("Print", { "Server", Lang:Get("VoteExtend", { RTV.DefaultExtend }) })
        return RTV:ResetVote(nil, 1, true, nil, true)
    elseif won == 7 then
        RTV.VotePossible = false

        if MapList and #MapList > 0 then
            local nValue = RTV:TrueRandom(1, #MapList)
            local tabWin = MapList[nValue]
            local map = tabWin[1]

            BHDATA:Broadcast("Print", { "Server", Lang:Get("VoteChange", {map}) })
            RunConsoleCommand("changelevel", map)
        else
            won = RTV:TrueRandom(1, 5)
        end
    end

    local map = RTV.Selections[won]
    if not map or not type(map) == "string" then return end

    BHDATA:Broadcast("Print", { "Server", Lang:Get("VoteChange", { map }) })
    if not RTV:IsAvailable(map) then
        BHDATA:Broadcast("Print", { "Server", Lang:Get("VoteMissing", { map }) })
    end

    BHDATA:Unload()
    RTV:CreateTimer("ChangeLevel", BHOP.RTV.ChangeMapTime, function() RunConsoleCommand("changelevel", map) end)
end

function RTV:ResetVote(no, multi, extend, msg, nominate)
    multi = multi or 1
    if no == "Yes" then RTV.CancelVote = nil end

    RTV.VotePossible = false
    RTV.Selections = {}
    if nominate then RTV.Nominations = {} end

    RTV.MapInit = CurTime()
    RTV.MapEnd = RTV.MapInit + (multi * RTV.DefaultExtend * 60)
    RTV.MapVotes = 0
    RTV.MapVoteList = {0, 0, 0, 0, 0, 0, 0}

    if extend then RTV.Extends = RTV.Extends + 1 end

    for _, p in ipairs(player.GetHumans()) do
        p.Rocked = nil
        if nominate then p.NominatedMap = nil end
    end

    timer.Create("RTV_MapCountdown", multi * RTV.DefaultExtend * 60, 1, function() RTV:StartVote() end)

    if msg then
        BHDATA:Broadcast("Print", {"Server", Lang:Get(msg)})
    end
end

function RTV:CreateTimer(name, delay, func)
    timer.Create(name, delay, 1, func)
end

function RTV:Vote(ply)
    if ply.RTVLimit and CurTime() - ply.RTVLimit < 12 then
        return NETWORK:StartNetworkMessageTimer(ply, "Print", {"Server", Lang:Get("VoteLimit", {math.ceil(12 - (CurTime() - ply.RTVLimit))})})
    elseif ply.Rocked then
        return NETWORK:StartNetworkMessageTimer(ply, "Print", {"Server", Lang:Get("VoteAlready")})
    elseif RTV.VotePossible then
        return NETWORK:StartNetworkMessageTimer(ply, "Print", {"Server", Lang:Get("VotePeriod")})
    end

    ply.RTVLimit = CurTime()
    ply.Rocked = true

    RTV.MapVotes = RTV.MapVotes + 1
    RTV.Required = math.max(math.ceil((#player.GetHumans() - Spectator:GetAFK()) * (BHOP.RTV.AmountNeeded)), 1)
    local nVotes = RTV.Required - RTV.MapVotes
    BHDATA:Broadcast("Print", {"Server", Lang:Get("VotePlayer", {ply:Name(), nVotes, nVotes == 1 and "vote" or "votes"})})

    if RTV.MapVotes >= RTV.Required and RTV.MapVotes > 0 then
        RTV:StartVote()
    end
end

function RTV:Revoke(ply)
    if RTV.VotePossible then
        return NETWORK:StartNetworkMessageTimer(ply, "Print", {"Server", Lang:Get("VotePeriod")})
    end

    if ply.Rocked then
        ply.Rocked = false

        RTV.MapVotes = RTV.MapVotes - 1
        RTV.Required = math.ceil((#player.GetHumans() - Spectator:GetAFK()) * (BHOP.RTV.AmountNeeded))
        local nVotes = RTV.Required - RTV.MapVotes
        BHDATA:Broadcast("Print", {"Server", Lang:Get("VoteRevoke", {ply:Name(), nVotes, nVotes == 1 and "vote" or "votes"})})
    else
        NETWORK:StartNetworkMessageTimer(ply, "Print", {"Server", Lang:Get("RevokeFail")})
    end
end

function RTV:Nominate(ply, map)
    local szIdentifier = "Nomination"
    local varArgs = {ply:Name(), map}

    if ply.NominatedMap and ply.NominatedMap ~= map then
        if RTV.Nominations[ply.NominatedMap] then
            for id, p in ipairs(RTV.Nominations[ply.NominatedMap]) do
                if p == ply then
                    table.remove(RTV.Nominations[ply.NominatedMap], id)
                    if #RTV.Nominations[ply.NominatedMap] == 0 then
                        RTV.Nominations[ply.NominatedMap] = nil
                    end

                    szIdentifier = "NominationChange"
                    varArgs = {ply:Name(), ply.NominatedMap, map}
                    break
                end
            end
        end
    elseif ply.NominatedMap == map then
        return NETWORK:StartNetworkMessageTimer(ply, "Print", {"Server", Lang:Get("NominationAlready")})
    end

    RTV.Nominations[map] = RTV.Nominations[map] or {}
    if not table.HasValue(RTV.Nominations[map], ply) then
        table.insert(RTV.Nominations[map], ply)
        ply.NominatedMap = map
        BHDATA:Broadcast("Print", {"Server", Lang:Get(szIdentifier, varArgs)})
    else
        NETWORK:StartNetworkMessageTimer(ply, "Print", {"Server", Lang:Get("NominationAlready")})
    end
end

function RTV:ReceiveVote(ply, vote, old)
    if not RTV.VotePossible or not vote then return end
    local add = ply.IsVIP and ply.VIPLevel and ply.VIPLevel >= Admin.Level.Elevated and 1 or 1

    if not nOld then
        if vote < 1 or vote > 7 then return end
        RTV.MapVoteList[vote] = RTV.MapVoteList[vote] + add
    else
        if vote < 1 or vote > 7 or old < 1 or old > 7 then return end
        RTV.MapVoteList[vote] = RTV.MapVoteList[vote] + add
        RTV.MapVoteList[old] = RTV.MapVoteList[old] - add
        if RTV.MapVoteList[old] < 0 then RTV.MapVoteList[old] = 0 end
    end

    BHDATA:Broadcast("RTV", {"VoteList", RTV.MapVoteList})

    UI:SendToClient(false, "MapVote", "update", RTV.MapVoteList)
    NETWORK:GetNetworkMessage(ply, "MapVote", RTV.MapVoteList)
end

NETWORK:GetNetworkMessage("VoteCallback", function(ply, data)
    local mapId = data[1]
    local oldId = data[2]
    RTV:ReceiveVote(ply, mapId, oldId)
end)

function RTV:IsAvailable(szMap)
    return file.Exists("maps/" .. szMap .. ".bsp", "GAME")
end

function RTV:Who(ply)
    local Voted = {}
    local NotVoted = {}

    for _, p in ipairs(player.GetHumans()) do
        if p.Rocked then
            table.insert(Voted, p:Name())
        else
            table.insert(NotVoted, p:Name())
        end
    end

    RTV.Required = math.ceil((#player.GetHumans() - Spectator:GetAFK()) * (BHOP.RTV.AmountNeeded))
    NETWORK:StartNetworkMessageTimer(ply, "Print", {"Server", Lang:Get("VoteList", {RTV.Required, #Voted, table.concat(Voted, ", "), #NotVoted, table.concat(NotVoted, ", ")})})
end

function RTV:CheckVotes()
    for _, ply in ipairs(player.GetHumans()) do
        if ply.AFK and ply.Rocked then
            ply.Rocked = false
            RTV.MapVotes = RTV.MapVotes - 1
            RTV.Required = math.max(math.ceil((#player.GetHumans() - Spectator:GetAFK()) * (BHOP.RTV.AmountNeeded)), 1)
        end
    end

    local required = math.max(math.ceil((#player.GetHumans() - Spectator:GetAFK()) * (BHOP.RTV.AmountNeeded)), 1)
    if RTV.MapVotes >= required and RTV.MapVotes > 0 then
        RTV:StartVote()
    end
end

function RTV:Check(ply)
    RTV.Required = math.ceil((#player.GetHumans() - Spectator:GetAFK()) * (BHOP.RTV.AmountNeeded))
    local nVotes = RTV.Required - RTV.MapVotes
    NETWORK:StartNetworkMessageTimer(ply, "Print", {"Server", Lang:Get("VoteCheck", {nVotes, nVotes == 1 and "vote" or "votes"})})
end

function RTV:VIPExtend(ply)
    if RTV.VotePossible then
        if RTV.VIPRequired then
            BHDATA:Broadcast("RTV", {"VIPExtend"})
            RTV:CreateTimer("EndVote", 31, function() RTV:EndVote() end)

            RTV.VIPTriggered = ply
            RTV.VIPRequired = nil
        else
            if not RTV.VIPTriggered then
                NETWORK:StartNetworkMessageTimer(ply, "Print", {"Server", "You can only use this command when people want to extend the map more than 2 times."})
            elseif ply ~= RTV.VIPTriggered then
                NETWORK:StartNetworkMessageTimer(ply, "Print", {"Server", "Your fellow VIP " .. RTV.VIPTriggered:Name() .. " has already triggered the extend vote."})
            else
                NETWORK:StartNetworkMessageTimer(ply, "Print", {"Server", "You cannot use this command again in the same session."})
            end
        end
    else
        NETWORK:StartNetworkMessageTimer(ply, "Print", {"Server", "You can only use this command while a vote is active!"})
    end
end

function RTV:LoadData()
    MapList = {}

    MySQL:Start("SELECT map, multiplier, plays FROM timer_map", function(results)
        if not results or #results == 0 then
            print("[RTV] No maps found in MySQL database!")
            return
        end

        for _, data in ipairs(results) do
            table.insert(MapList, {
                data["map"],
                tonumber(data["multiplier"]) or 0,
                tonumber(data["plays"]) or 0
            })
        end
    end)

    file.CreateDir("rtv/")

    if not file.Exists("rtv/settings.txt", "DATA") then
        file.Write("rtv/settings.txt", tostring(RTV.MapListVersion))
    else
        local data = file.Read("rtv/settings.txt", "DATA")
        RTV.MapListVersion = tonumber(data)
    end
end

function RTV:UpdateMapListVersion()
    RTV.MapListVersion = RTV.MapListVersion + 1
    file.Write("rtv/settings.txt", tostring(RTV.MapListVersion))
end

local EncodedData, EncodedLength
function RTV:GetMapList(ply, ver)
    if ver ~= RTV.MapListVersion then
        if not EncodedData or not EncodedLength then
            EncodedData = util.Compress(util.TableToJSON({MapList, RTV.MapListVersion}))
            EncodedLength = #EncodedData
        end

        if not EncodedData or not EncodedLength then
            NETWORK:StartNetworkMessageTimer(ply, "Print", {"Server", "Couldn't obtain map list, please reconnect!"})
        else
            net.Start("BinaryTransfer")
            net.WriteString("List")
            net.WriteUInt(EncodedLength, 16)
            net.WriteData(EncodedData, EncodedLength)
            net.Send(ply)
        end
    end
end

function RTV:MapExists(map)
    for _, data in ipairs(MapList) do
        if data[1] == map then
            return true
        end
    end
    return false
end

function RTV:GetMapData(map)
    for _, data in ipairs(MapList) do
        if data[1] == map then
            return data
        end
    end
    return {map, 1}
end

function RTV:TrueRandom(up, down)
    if not RTV.RandomInit then
        math.randomseed(os.time() + math.random())
        RTV.RandomInit = true
    end

    return math.random(up, down)
end

hook_Add("InitPostEntity", "InitializeRTV", function()
    RTV:Init()
end)

function RTV:SendMapList(client)
    local mapList = {}
    local seenMaps = {}

    for _, data in ipairs(MapList) do
        local mapName = tostring(data[1])
        local points = tonumber(data[2]) or 0

        if not seenMaps[mapName] and points > 0 then
            seenMaps[mapName] = true

            table.insert(mapList, { 
                name = mapName, 
                points = points
            })
        end
    end

    UI:SendToClient(client or false, "nominate_list", mapList)
end

hook.Add("PlayerInitialSpawn", "SendNominateList", function(client)
    RTV:SendMapList(client)
end)