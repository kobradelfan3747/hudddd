if not Config.Radio or not Config.Radio.Enabled then
    return
end

local radios = {}

local function stationTracks(station)
    local tracks = {}
    if type(station) ~= 'table' then
        return tracks
    end

    local sourceList = station.tracks or station.Tracks or {}
    for _, url in ipairs(sourceList) do
        if type(url) == 'string' then
            url = url:gsub('^%s+', ''):gsub('%s+$', '')
            if url ~= '' then
                tracks[#tracks + 1] = url
            end
        end
    end

    return tracks
end

local function findStation(id)
    if type(id) ~= 'string' or id == '' then
        return nil
    end

    for _, station in ipairs(Config.Radio.Stations or {}) do
        if type(station) == 'table' and station.id == id then
            return station
        end
    end

    return nil
end

local function pickTrack(tracks, avoid)
    if #tracks == 0 then
        return nil
    end

    if #tracks == 1 then
        return tracks[1]
    end

    local url = tracks[math.random(1, #tracks)]
    if avoid and url == avoid then
        url = tracks[math.random(1, #tracks)]
    end

    return url
end

local function playerVehicle(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then
        return nil, nil
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if not vehicle or vehicle == 0 then
        return nil, nil
    end

    return vehicle, NetworkGetNetworkIdFromEntity(vehicle)
end

local function playerSeat(src, vehicle)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not vehicle then
        return nil
    end

    for seat = -1, 6 do
        if GetPedInVehicleSeat(vehicle, seat) == ped then
            return seat
        end
    end

    return nil
end

local function canControl(src)
    local vehicle = playerVehicle(src)
    if not vehicle then
        return false
    end

    local seat = playerSeat(src, vehicle)
    local allowed = Config.Radio.ControllerSeats or { -1, 0 }
    for _, value in ipairs(allowed) do
        if seat == value then
            return true
        end
    end

    return false
end

local function packState(netId, state)
    if not state then
        return { netId = netId, id = nil, url = '', volume = 0.0, label = '' }
    end

    return {
        netId = netId,
        id = state.id,
        url = state.url,
        volume = state.volume,
        label = state.label
    }
end

local function broadcast(netId)
    TriggerClientEvent('vn-hud:client:radioState', -1, packState(netId, radios[netId]))
end

local function setStation(src, id, volume)
    if not canControl(src) then
        return
    end

    local vehicle, netId = playerVehicle(src)
    if not vehicle or not netId then
        return
    end

    if type(id) ~= 'string' or id == '' then
        radios[netId] = nil
        broadcast(netId)
        return
    end

    local station = findStation(id)
    local tracks = stationTracks(station)
    if not station or #tracks == 0 then
        return
    end

    if not volume and radios[netId] then
        volume = radios[netId].volume
    end
    volume = math.max(0.0, math.min(1.0, tonumber(volume) or Config.Radio.DefaultVolume or 0.55))

    radios[netId] = {
        id = station.id,
        url = pickTrack(tracks),
        volume = volume,
        label = station.label or station.id
    }

    broadcast(netId)
end

RegisterNetEvent('vn-hud:server:radioSet')
AddEventHandler('vn-hud:server:radioSet', function(payload)
    local src = source
    if type(payload) ~= 'table' then
        return
    end
    setStation(src, payload.id, payload.volume)
end)

RegisterNetEvent('vn-hud:server:radioNext')
AddEventHandler('vn-hud:server:radioNext', function(netId)
    netId = tonumber(netId)
    if not netId or not radios[netId] then
        return
    end

    local state = radios[netId]
    local station = findStation(state.id)
    local tracks = stationTracks(station)
    if #tracks == 0 then
        radios[netId] = nil
        broadcast(netId)
        return
    end

    state.url = pickTrack(tracks, state.url)
    broadcast(netId)
end)

RegisterNetEvent('vn-hud:server:radioVolume')
AddEventHandler('vn-hud:server:radioVolume', function(volume)
    local src = source
    volume = tonumber(volume)
    if not volume or not canControl(src) then
        return
    end

    local _, netId = playerVehicle(src)
    if not netId or not radios[netId] then
        return
    end

    radios[netId].volume = math.max(0.0, math.min(1.0, volume))
    broadcast(netId)
end)

RegisterNetEvent('vn-hud:server:radioRequest')
AddEventHandler('vn-hud:server:radioRequest', function(netId)
    netId = tonumber(netId)
    if not netId then
        return
    end

    TriggerClientEvent('vn-hud:client:radioState', source, packState(netId, radios[netId]))
end)

RegisterNetEvent('vn-hud:server:radioSyncAll')
AddEventHandler('vn-hud:server:radioSyncAll', function()
    local list = {}
    for netId, state in pairs(radios) do
        list[#list + 1] = packState(netId, state)
    end
    TriggerClientEvent('vn-hud:client:radioWorld', source, list)
end)

CreateThread(function()
    while true do
        Wait(15000)
        for netId, _ in pairs(radios) do
            local entity = NetworkGetEntityFromNetworkId(netId)
            if not entity or entity == 0 or not DoesEntityExist(entity) then
                radios[netId] = nil
                broadcast(netId)
            end
        end
    end
end)
