if not Config.Radio or not Config.Radio.Enabled then
    return
end

local radioOpen = false
local cabinVolume = tonumber(Config.Radio.DefaultVolume) or 0.55
local worldRadios = {}
local activeNetId = nil
local lastVehicle = 0
local lastApply = { id = nil, url = '', volume = -1.0 }

local function sendRadio(action, payload)
    payload = payload or {}
    payload.action = action
    SendNUIMessage(payload)
end

local function currentVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        return 0
    end
    return GetVehiclePedIsIn(ped, false)
end

local function vehicleNetId(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil
    end
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId == 0 then
        return nil
    end
    return netId
end

local function playerSeat(vehicle)
    local ped = PlayerPedId()
    if vehicle == 0 then
        return nil
    end
    for seat = -1, 6 do
        if GetPedInVehicleSeat(vehicle, seat) == ped then
            return seat
        end
    end
    return nil
end

local function canControl()
    local vehicle = currentVehicle()
    local seat = playerSeat(vehicle)
    if seat == nil then
        return false
    end
    for _, value in ipairs(Config.Radio.ControllerSeats or { -1, 0 }) do
        if seat == value then
            return true
        end
    end
    return false
end

local function stationReady(station)
    if type(station) ~= 'table' then
        return false
    end
    for _, url in ipairs(station.tracks or {}) do
        if type(url) == 'string' and url:gsub('%s+', '') ~= '' then
            return true
        end
    end
    return false
end

local function visibleStations()
    local list = {}
    for index, station in ipairs(Config.Radio.Stations or {}) do
        if type(station) == 'table' and type(station.id) == 'string' then
            list[#list + 1] = {
                id = station.id,
                label = station.label or station.id,
                index = index,
                ready = stationReady(station)
            }
        end
    end
    return list
end

local function stopNativeRadio(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end
    SetVehRadioStation(vehicle, 'OFF')
    SetVehicleRadioEnabled(vehicle, false)
end

local function applyAudio(state, outputVolume, syncSlider)
    local url = (state and state.url) or ''
    local id = state and state.id or nil
    local volume = math.max(0.0, math.min(1.0, tonumber(outputVolume) or 0.0))

    if lastApply.id == id and lastApply.url == url and math.abs(lastApply.volume - volume) < 0.01 then
        return
    end

    lastApply.id = id
    lastApply.url = url
    lastApply.volume = volume

    sendRadio('radio:play', {
        id = id,
        label = state and state.label or '',
        url = url,
        volume = volume,
        cabinVolume = state and state.volume or cabinVolume,
        syncSlider = syncSlider == true
    })
end

local function closeRadio()
    if not radioOpen then
        return
    end
    radioOpen = false
    SetNuiFocus(false, false)
    sendRadio('radio:visibility', { visible = false })
end

local function openRadio()
    if radioOpen then
        closeRadio()
        return
    end

    if not canControl() then
        return
    end

    local netId = vehicleNetId(currentVehicle())
    local state = netId and worldRadios[netId] or nil

    radioOpen = true
    SetNuiFocus(true, true)
    sendRadio('radio:open', {
        stations = visibleStations(),
        current = state and state.id or nil,
        volume = state and state.volume or cabinVolume
    })
end

RegisterCommand('vnhud_radio', function()
    if IsPauseMenuActive() or IsScreenFadedOut() then
        return
    end
    if IsNuiFocused() and not radioOpen then
        return
    end
    if not canControl() then
        return
    end
    openRadio()
end, false)

RegisterKeyMapping('vnhud_radio', 'Vehicle radio', 'keyboard', Config.Radio.OpenKey or 'Q')

RegisterNUICallback('vnRadioReady', function(_, cb)
    sendRadio('radio:configure', {
        stations = visibleStations(),
        volume = cabinVolume
    })
    TriggerServerEvent('vn-hud:server:radioSyncAll')
    cb({ ok = true })
end)

RegisterNUICallback('vnRadioClose', function(_, cb)
    closeRadio()
    cb({ ok = true })
end)

RegisterNUICallback('vnRadioSelect', function(data, cb)
    cb({ ok = true })
    if type(data) ~= 'table' or not canControl() then
        return
    end

    local id = data.id
    if type(id) ~= 'string' then
        return
    end

    local netId = vehicleNetId(currentVehicle())
    local state = netId and worldRadios[netId] or nil
    if state and state.id == id then
        TriggerServerEvent('vn-hud:server:radioSet', { id = nil })
        return
    end

    TriggerServerEvent('vn-hud:server:radioSet', { id = id, volume = cabinVolume })
end)

RegisterNUICallback('vnRadioEnded', function(_, cb)
    cb({ ok = true })
    local netId = vehicleNetId(currentVehicle()) or activeNetId
    if netId then
        TriggerServerEvent('vn-hud:server:radioNext', netId)
    end
end)

RegisterNUICallback('vnRadioVolume', function(data, cb)
    cb({ ok = true })
    local volume = tonumber(data and data.volume)
    if not volume then
        return
    end
    cabinVolume = math.max(0.0, math.min(1.0, volume))
    local netId = vehicleNetId(currentVehicle())
    if netId and worldRadios[netId] then
        worldRadios[netId].volume = cabinVolume
    end
    if canControl() then
        TriggerServerEvent('vn-hud:server:radioVolume', cabinVolume)
    end
end)

RegisterNetEvent('vn-hud:client:radioState', function(state)
    if type(state) ~= 'table' or not tonumber(state.netId) then
        return
    end

    local netId = tonumber(state.netId)
    if not state.id or not state.url or state.url == '' then
        worldRadios[netId] = nil
    else
        worldRadios[netId] = {
            id = state.id,
            url = state.url,
            volume = tonumber(state.volume) or cabinVolume,
            label = state.label or ''
        }
        cabinVolume = worldRadios[netId].volume
    end
end)

RegisterNetEvent('vn-hud:client:radioWorld', function(list)
    worldRadios = {}
    if type(list) ~= 'table' then
        return
    end
    for _, state in ipairs(list) do
        if type(state) == 'table' and tonumber(state.netId) and state.url and state.url ~= '' then
            worldRadios[tonumber(state.netId)] = {
                id = state.id,
                url = state.url,
                volume = tonumber(state.volume) or cabinVolume,
                label = state.label or ''
            }
        end
    end
end)

CreateThread(function()
    SetUserRadioControlEnabled(false)
    TriggerServerEvent('vn-hud:server:radioSyncAll')

    local exterior = Config.Radio.Exterior or {}
    local exteriorEnabled = exterior.Enabled ~= false
    local maxDistance = tonumber(exterior.MaxDistance) or 12.0
    local volumeScale = tonumber(exterior.VolumeScale) or 0.04

    while true do
        local vehicle = currentVehicle()

        if vehicle ~= 0 then
            DisableControlAction(0, 81, true)
            DisableControlAction(0, 82, true)
            DisableControlAction(0, 83, true)
            DisableControlAction(0, 84, true)
            DisableControlAction(0, 85, true)
            DisableControlAction(0, 332, true)
            DisableControlAction(0, 333, true)
            stopNativeRadio(vehicle)

            local netId = vehicleNetId(vehicle)
            if vehicle ~= lastVehicle and netId then
                TriggerServerEvent('vn-hud:server:radioRequest', netId)
            end

            local state = netId and worldRadios[netId] or nil
            if state then
                applyAudio(state, state.volume or cabinVolume, radioOpen)
                activeNetId = netId
            elseif activeNetId ~= nil then
                applyAudio(nil, 0.0, radioOpen)
                activeNetId = nil
            end

            if radioOpen and (IsPauseMenuActive() or IsScreenFadedOut() or not canControl()) then
                closeRadio()
            end

            lastVehicle = vehicle
            Wait(0)
        else
            if radioOpen then
                closeRadio()
            end

            lastVehicle = 0
            local chosen, chosenDist = nil, nil

            if exteriorEnabled then
                local coords = GetEntityCoords(PlayerPedId())
                for netId, state in pairs(worldRadios) do
                    if state.url and state.url ~= '' then
                        local entity = 0
                        if NetworkDoesNetworkIdExist(netId) then
                            entity = NetworkGetEntityFromNetworkId(netId)
                        end
                        if entity ~= 0 and DoesEntityExist(entity) then
                            local dist = #(coords - GetEntityCoords(entity))
                            if dist <= maxDistance and (not chosenDist or dist < chosenDist) then
                                chosen = state
                                chosenDist = dist
                                activeNetId = netId
                            end
                        end
                    end
                end
            end

            if chosen and chosenDist then
                local fade = 1.0 - (chosenDist / maxDistance)
                fade = fade * fade
                applyAudio(chosen, (chosen.volume or cabinVolume) * volumeScale * fade, false)
            elseif activeNetId ~= nil then
                applyAudio(nil, 0.0, false)
                activeNetId = nil
            end

            Wait(200)
        end
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        closeRadio()
        SetUserRadioControlEnabled(true)
    end
end)
