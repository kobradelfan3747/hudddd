local vehicleState = {
    vehicle = 0,
    visible = false,
    seatbelt = false,
    engineOff = false,
    leftIndicator = false,
    rightIndicator = false,
    hazard = false,
    indicatorExpires = 0,
    tripKm = 0.0,
    lastCoords = nil,
    previousSpeedKmh = 0.0,
    previousVelocity = vector3(0.0, 0.0, 0.0),
    lastEjectAt = 0,
    manualLights = nil,
    lastLayoutSignature = nil,
    lastPayloadKey = nil,
    lastBeltNotify = 0,
    lastEngineNotify = 0,
    chimeOn = false,
    lastChimeRequest = 0
}

local esxObject = nil

local function getESX()
    if esxObject then
        return esxObject
    end

    if GetResourceState('es_extended') == 'started' then
        local ok, shared = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok and type(shared) == 'table' then
            esxObject = shared
            return esxObject
        end
    end

    TriggerEvent('esx:getSharedObject', function(shared)
        if type(shared) == 'table' then
            esxObject = shared
        end
    end)

    return esxObject
end

local function showEsxNotify(message)
    if type(message) ~= 'string' or message == '' then
        return
    end

    local ok = pcall(function()
        exports['es_extended']:ShowNotification(message)
    end)
    if ok then
        return
    end

    local shared = getESX()
    if shared and type(shared.ShowNotification) == 'function' then
        ok = pcall(shared.ShowNotification, message)
        if ok then
            return
        end
    end

    TriggerEvent('esx:showNotification', message)
end

local function engineIsRunning(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end
    if vehicleState.engineOff then
        return false
    end
    local running = GetIsVehicleEngineRunning(vehicle)
    return running == true or running == 1
end

local function setSeatbeltChime(on, force)
    on = on == true
    if not force and vehicleState.chimeOn == on then
        return
    end

    vehicleState.chimeOn = on
    vehicleState.lastChimeRequest = on and GetGameTimer() or 0

    local seatbelt = Config.Vehicle.Seatbelt or {}
    SendNUIMessage({
        action = 'seatbelt:warn',
        playing = on,
        file = on and (seatbelt.WarningFile or 'm.mp3') or nil
    })
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function getCurrentVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return 0 end
    return GetVehiclePedIsIn(ped, false)
end

local function isDriver(vehicle)
    return vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == PlayerPedId()
end

local function isSeatbeltAvailable(vehicle)
    if not Config.Vehicle.Seatbelt.Enabled or vehicle == 0 then return false end

    local class = GetVehicleClass(vehicle)
    return class ~= 8
        and class ~= 13
        and class ~= 14
        and class ~= 15
        and class ~= 16
        and class ~= 21
end

local function needsSeatbeltWarning(vehicle)
    return vehicle ~= 0
        and isSeatbeltAvailable(vehicle)
        and not vehicleState.seatbelt
end

local function getLightsOn(vehicle)
    local _, lowBeams, highBeams = GetVehicleLightsState(vehicle)
    return lowBeams == true or lowBeams == 1 or highBeams == true or highBeams == 1
end

local function getGear(vehicle, speedKmh)
    if not engineIsRunning(vehicle) then
        return 'N'
    end

    local relativeSpeed = GetEntitySpeedVector(vehicle, true)
    if relativeSpeed and relativeSpeed.y < -0.55 then return 'R' end

    local gear = tonumber(GetVehicleCurrentGear(vehicle)) or 0
    if speedKmh < 1.0 and gear == 0 then return 'N' end
    if gear <= 0 then return 'D' end
    return tostring(gear)
end

local function applyIndicators()
    local vehicle = vehicleState.vehicle
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    SetVehicleIndicatorLights(vehicle, 1, vehicleState.leftIndicator or vehicleState.hazard)
    SetVehicleIndicatorLights(vehicle, 0, vehicleState.rightIndicator or vehicleState.hazard)
end

local function clearIndicators()
    local vehicle = vehicleState.vehicle
    vehicleState.leftIndicator = false
    vehicleState.rightIndicator = false
    vehicleState.hazard = false
    vehicleState.indicatorExpires = 0

    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        SetVehicleIndicatorLights(vehicle, 1, false)
        SetVehicleIndicatorLights(vehicle, 0, false)
    end
end

local function resetVehicleState(newVehicle)
    local previousVehicle = vehicleState.vehicle
    if previousVehicle ~= 0 and previousVehicle ~= newVehicle then
        clearIndicators()


        if vehicleState.manualLights ~= nil and DoesEntityExist(previousVehicle) then
            SetVehicleLights(previousVehicle, 0)
        end
    end

    vehicleState.vehicle = newVehicle or 0
    vehicleState.seatbelt = false
    vehicleState.engineOff = false
    vehicleState.manualLights = nil
    vehicleState.tripKm = 0.0
    vehicleState.lastCoords = nil
    vehicleState.previousSpeedKmh = 0.0
    vehicleState.previousVelocity = vector3(0.0, 0.0, 0.0)
    vehicleState.lastPayloadKey = nil
    vehicleState.lastBeltNotify = 0
    vehicleState.lastEngineNotify = 0
    setSeatbeltChime(false, true)

    if newVehicle == 0 then clearIndicators() end
end

local function sendVehicleConfiguration()
    SendNUIMessage({
        action = 'vehicle:configure',
        config = {
            centerBottomVh = Config.Vehicle.CenterBottomVh,
            accent = Config.Vehicle.AccentColor,
            warning = Config.Vehicle.WarningColor,
            danger = Config.Vehicle.DangerColor,
            gearColor = Config.Vehicle.GearColor
        }
    })
end

local function getRailLayout()
    local safeZone = clamp(GetSafeZoneSize(), 0.9, 1.0)
    local resolutionX, resolutionY = GetActiveScreenResolution()
    resolutionX = math.max(1, resolutionX)
    resolutionY = math.max(1, resolutionY)

    local aspectRatio = resolutionX / resolutionY
    local safeInset = math.abs(safeZone - 1.0) * 0.5
    local minimapWidth = 1.0 / (4.0 * aspectRatio)
    local minimapHeight = 1.0 / 5.674
    local minimapBottom = 1.0 - safeInset - Config.Minimap.MoveUp

    return {
        left = (safeInset * resolutionX)
            + (minimapWidth * resolutionX)
            + Config.Vehicle.RailGapPx
            + Config.Vehicle.RailOffsetX,
        top = ((minimapBottom - minimapHeight) * resolutionY) + Config.Vehicle.RailOffsetY,
        height = minimapHeight * resolutionY,
        signature = ('%d:%d:%.3f'):format(resolutionX, resolutionY, safeZone)
    }
end

local function sendVehicleLayout(force)
    local layout = getRailLayout()
    if not force and layout.signature == vehicleState.lastLayoutSignature then return end

    vehicleState.lastLayoutSignature = layout.signature
    SendNUIMessage({ action = 'vehicle:layout', layout = layout })
end

local function setVehicleVisible(visible)
    visible = visible == true
    if vehicleState.visible == visible then return end

    vehicleState.visible = visible
    SendNUIMessage({ action = 'vehicle:visibility', visible = visible })
end

local function updateTrip(vehicle)
    local coords = GetEntityCoords(vehicle)
    if vehicleState.lastCoords then
        local dx = coords.x - vehicleState.lastCoords.x
        local dy = coords.y - vehicleState.lastCoords.y
        local dz = coords.z - vehicleState.lastCoords.z
        local distance = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))


        if distance > 0.01 and distance < 100.0 then
            vehicleState.tripKm = vehicleState.tripKm + (distance / 1000.0)
        end
    end
    vehicleState.lastCoords = coords
end

local function getPedSeat(vehicle, ped)
    for seat = -1, GetVehicleMaxNumberOfPassengers(vehicle) do
        if GetPedInVehicleSeat(vehicle, seat) == ped then
            return seat
        end
    end
    return -1
end

local function seatThrowSide(seat)
    if seat == -1 or seat == 1 or seat == 3 or seat == 5 then
        return -1.0
    end
    return 1.0
end

local function ejectPlayer(vehicle)
    local ped = PlayerPedId()
    local seatbelt = Config.Vehicle.Seatbelt or {}
    local side = seatThrowSide(getPedSeat(vehicle, ped))
    local vel = vehicleState.previousVelocity
    local speed = math.sqrt((vel.x * vel.x) + (vel.y * vel.y) + (vel.z * vel.z))
    local sideForce = tonumber(seatbelt.EjectionSideForce) or 11.5
    local upForce = tonumber(seatbelt.EjectionUpForce) or 5.4
    local forwardScale = tonumber(seatbelt.EjectionForwardScale) or 0.34
    local ragdollMs = math.floor(tonumber(seatbelt.EjectionRagdollMs) or 5600)
    local throw = sideForce + math.min(16.0, speed * 0.62)

    local origin = GetEntityCoords(vehicle)
    local rightPoint = GetOffsetFromEntityInWorldCoords(vehicle, 1.0, 0.0, 0.0)
    local right = vector3(rightPoint.x - origin.x, rightPoint.y - origin.y, rightPoint.z - origin.z)
    local forward = GetEntityForwardVector(vehicle)
    local exitPos = GetOffsetFromEntityInWorldCoords(vehicle, side * 1.18, 0.18, 0.92)

    vehicleState.seatbelt = false
    ClearPedTasksImmediately(ped)
    SetPedCanRagdoll(ped, true)
    if DoesEntityExist(vehicle) then
        SetEntityCollision(vehicle, false, false)
    end
    SetEntityCoordsNoOffset(ped, exitPos.x, exitPos.y, exitPos.z, false, false, false)
    SetEntityCollision(ped, true, true)

    local outX = vel.x + (right.x * side * throw) + (forward.x * throw * forwardScale)
    local outY = vel.y + (right.y * side * throw) + (forward.y * throw * forwardScale)
    local outZ = math.max(3.8, vel.z + upForce + math.min(5.5, speed * 0.16))
    SetEntityVelocity(ped, outX, outY, outZ)
    SetPedToRagdoll(ped, ragdollMs, ragdollMs, 0, false, false, false)
    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.16)

    CreateThread(function()
        Wait(0)
        if DoesEntityExist(ped) then
            ApplyForceToEntity(
                ped, 1,
                right.x * side * (throw * 1.35),
                right.y * side * (throw * 1.35),
                upForce * 1.1,
                0.0, 0.0, 0.0,
                0, false, true, true, false, true
            )
        end
        Wait(40)
        if DoesEntityExist(ped) and not IsPedRagdoll(ped) then
            SetPedToRagdoll(ped, ragdollMs, ragdollMs, 0, false, false, false)
        end
        Wait(160)
        if DoesEntityExist(vehicle) then
            SetEntityCollision(vehicle, true, true)
        end
    end)
end

local function processEjection(vehicle, speedKmh, seatbeltAvailable)
    if not Config.Vehicle.Seatbelt.EjectionEnabled or not seatbeltAvailable or vehicleState.seatbelt then
        vehicleState.previousSpeedKmh = speedKmh
        vehicleState.previousVelocity = GetEntityVelocity(vehicle)
        return
    end

    local previous = vehicleState.previousSpeedKmh
    local hardStop = previous >= Config.Vehicle.Seatbelt.EjectionMinSpeedKmh
        and speedKmh <= previous * Config.Vehicle.Seatbelt.EjectionSpeedDropRatio
        and HasEntityCollidedWithAnything(vehicle)

    if hardStop and (GetGameTimer() - (vehicleState.lastEjectAt or 0)) > 2200 then
        vehicleState.lastEjectAt = GetGameTimer()
        ejectPlayer(vehicle)
    end

    vehicleState.previousSpeedKmh = speedKmh
    vehicleState.previousVelocity = GetEntityVelocity(vehicle)
end

local function buildVehiclePayload(vehicle)
    local speedKmh = GetEntitySpeed(vehicle) * 3.6
    local displaySpeed = Config.Vehicle.UseMph and speedKmh * 0.621371 or speedKmh
    local fuel = clamp(GetVehicleFuelLevel(vehicle), 0.0, 100.0)
    local engine = clamp(GetVehicleEngineHealth(vehicle) / 10.0, 0.0, 100.0)
    local running = engineIsRunning(vehicle)
    local rpm = 0.0
    if running then
        rpm = clamp((tonumber(GetVehicleCurrentRpm(vehicle)) or 0.0) * 100.0, 0.0, 100.0)
    else
        pcall(SetVehicleCurrentRpm, vehicle, 0.0)
    end
    local lockStatus = GetVehicleDoorLockStatus(vehicle)
    local seatbeltAvailable = isSeatbeltAvailable(vehicle)
    local lightsOn = vehicleState.manualLights

    if lightsOn == nil then
        lightsOn = getLightsOn(vehicle)
    elseif isDriver(vehicle) then

        SetVehicleLights(vehicle, lightsOn and 2 or 4)
        if not lightsOn then SetVehicleFullbeam(vehicle, false) end
    end

    updateTrip(vehicle)
    processEjection(vehicle, speedKmh, seatbeltAvailable)

    if vehicleState.indicatorExpires > 0 and GetGameTimer() >= vehicleState.indicatorExpires then
        clearIndicators()
    end

    return {
        speed = displaySpeed,
        unit = Config.Vehicle.UseMph and 'MP/H' or Config.Vehicle.SpeedUnit,
        rpm = rpm,
        gear = getGear(vehicle, speedKmh),
        fuel = fuel,
        engine = engine,
        trip = vehicleState.tripKm,
        seatbelt = vehicleState.seatbelt,
        seatbeltAvailable = seatbeltAvailable,
        lights = lightsOn,
        locked = lockStatus >= 2,
        leftIndicator = vehicleState.leftIndicator,
        rightIndicator = vehicleState.rightIndicator,
        hazard = vehicleState.hazard,
        engineRunning = running
    }
end

local function sendVehicleUpdate(force)
    local vehicle = getCurrentVehicle()
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        if vehicleState.vehicle ~= 0 then resetVehicleState(0) end
        setVehicleVisible(false)
        return false
    end

    if vehicle ~= vehicleState.vehicle then
        resetVehicleState(vehicle)
        sendVehicleLayout(true)
        SetTimeout(450, function()
            if getCurrentVehicle() ~= vehicle or not isDriver(vehicle) then
                return
            end
            if not engineIsRunning(vehicle) then
                local seatbelt = Config.Vehicle.Seatbelt or {}
                showEsxNotify(seatbelt.EngineOffMessage or 'Start the vehicle.')
                vehicleState.lastEngineNotify = GetGameTimer()
            end
        end)
    end

    local payload = buildVehiclePayload(vehicle)
    local visible = not IsPauseMenuActive()
    setVehicleVisible(visible)

    local key = ('%d:%.1f:%s:%.1f:%.1f:%.1f:%s:%s:%s:%s:%s:%s:%s:%s'):format(
        math.floor(payload.speed + 0.5),
        payload.rpm,
        payload.gear,
        payload.fuel,
        payload.engine,
        payload.trip,
        tostring(payload.seatbelt),
        tostring(payload.seatbeltAvailable),
        tostring(payload.lights),
        tostring(payload.locked),
        tostring(payload.leftIndicator),
        tostring(payload.rightIndicator),
        tostring(payload.hazard),
        tostring(payload.engineRunning)
    )

    if force or key ~= vehicleState.lastPayloadKey then
        vehicleState.lastPayloadKey = key
        payload.action = 'vehicle:update'
        SendNUIMessage(payload)
    end

    return true
end

local function toggleSeatbelt()
    local vehicle = getCurrentVehicle()
    if vehicle == 0 or not isSeatbeltAvailable(vehicle) then return end

    vehicleState.seatbelt = not vehicleState.seatbelt
    TriggerEvent('vn-hud:client:seatbeltChanged', vehicleState.seatbelt)

    local seatbelt = Config.Vehicle.Seatbelt or {}
    if vehicleState.seatbelt then
        showEsxNotify(seatbelt.FastenMessage or 'You fastened your seatbelt.')
    else
        showEsxNotify(seatbelt.UnfastenMessage or 'You unfastened your seatbelt.')
    end

    -- Stop immediately when fastening and restart immediately when unfastening.
    local playWarning = seatbelt.WarningChime ~= false and needsSeatbeltWarning(vehicle)
    setSeatbeltChime(playWarning, true)
    sendVehicleUpdate(true)
end

local function applyEngineState(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) or not isDriver(vehicle) then
        return
    end

    if vehicleState.engineOff then
        SetVehicleEngineOn(vehicle, false, true, true)
        SetVehicleUndriveable(vehicle, true)
    else
        SetVehicleUndriveable(vehicle, false)
    end
end

local function toggleEngine()
    local vehicle = getCurrentVehicle()
    if vehicle == 0 or not isDriver(vehicle) then
        return
    end

    if vehicleState.vehicle ~= vehicle then
        resetVehicleState(vehicle)
    end

    local running = GetIsVehicleEngineRunning(vehicle)
    vehicleState.engineOff = running == true or running == 1
    if vehicleState.engineOff then
        SetVehicleEngineOn(vehicle, false, false, true)
        SetVehicleUndriveable(vehicle, true)
        local seatbelt = Config.Vehicle.Seatbelt or {}
        showEsxNotify(seatbelt.EngineOffMessage or 'Start the vehicle.')
        vehicleState.lastEngineNotify = GetGameTimer()
    else
        SetVehicleUndriveable(vehicle, false)
        SetVehicleEngineOn(vehicle, true, false, true)
    end
    sendVehicleUpdate(true)
end

local function toggleLights()
    local vehicle = getCurrentVehicle()
    if vehicle == 0 or not isDriver(vehicle) then return end

    if vehicleState.vehicle ~= vehicle then resetVehicleState(vehicle) end
    if vehicleState.manualLights == nil then
        vehicleState.manualLights = getLightsOn(vehicle)
    end

    vehicleState.manualLights = not vehicleState.manualLights
    local lightsOn = vehicleState.manualLights


    SetVehicleLights(vehicle, lightsOn and 2 or 4)
    if not lightsOn then SetVehicleFullbeam(vehicle, false) end


    SetTimeout(80, function()
        if vehicleState.vehicle == vehicle and DoesEntityExist(vehicle) then
            SetVehicleLights(vehicle, lightsOn and 2 or 4)
            if not lightsOn then SetVehicleFullbeam(vehicle, false) end
            sendVehicleUpdate(true)
        end
    end)
end

local function toggleIndicator(side)
    local vehicle = getCurrentVehicle()
    if vehicle == 0 or not isDriver(vehicle) then return end

    if side == 'left' then
        vehicleState.leftIndicator = not vehicleState.leftIndicator
        vehicleState.rightIndicator = false
        vehicleState.hazard = false
    elseif side == 'right' then
        vehicleState.rightIndicator = not vehicleState.rightIndicator
        vehicleState.leftIndicator = false
        vehicleState.hazard = false
    elseif side == 'hazard' then
        vehicleState.hazard = not vehicleState.hazard
        vehicleState.leftIndicator = false
        vehicleState.rightIndicator = false
    end

    local active = vehicleState.leftIndicator or vehicleState.rightIndicator or vehicleState.hazard
    vehicleState.indicatorExpires = active and (GetGameTimer() + Config.Vehicle.IndicatorAutoCancelMs) or 0
    applyIndicators()
    sendVehicleUpdate(true)
end

RegisterCommand('vnhud_seatbelt', toggleSeatbelt, false)
RegisterCommand('vnhud_engine', toggleEngine, false)
RegisterCommand('vnhud_lights', toggleLights, false)
RegisterCommand('vnhud_indicator_left', function() toggleIndicator('left') end, false)
RegisterCommand('vnhud_indicator_right', function() toggleIndicator('right') end, false)
RegisterCommand('vnhud_hazard', function() toggleIndicator('hazard') end, false)

RegisterKeyMapping('vnhud_seatbelt', 'VN HUD: Toggle seatbelt', 'keyboard', Config.Vehicle.Controls.Seatbelt)
RegisterKeyMapping('vnhud_engine', 'VN HUD: Toggle engine', 'keyboard', Config.Vehicle.Controls.Engine or 'J')
RegisterKeyMapping('vnhud_lights', 'VN HUD: Toggle headlights', 'keyboard', Config.Vehicle.Controls.Headlights)
RegisterKeyMapping('vnhud_indicator_left', 'VN HUD: Left indicator', 'keyboard', Config.Vehicle.Controls.LeftIndicator)
RegisterKeyMapping('vnhud_indicator_right', 'VN HUD: Right indicator', 'keyboard', Config.Vehicle.Controls.RightIndicator)
RegisterKeyMapping('vnhud_hazard', 'VN HUD: Hazard lights', 'keyboard', Config.Vehicle.Controls.Hazard)

RegisterNUICallback('vnVehicleReady', function(_, callback)
    sendVehicleConfiguration()
    sendVehicleLayout(true)
    sendVehicleUpdate(true)

    local vehicle = getCurrentVehicle()
    local playWarning = Config.Vehicle.Seatbelt.WarningChime ~= false
        and needsSeatbeltWarning(vehicle)
    setSeatbeltChime(playWarning, true)
    callback({ ok = true })
end)

CreateThread(function()
    if not Config.Vehicle.Enabled then
        SendNUIMessage({ action = 'vehicle:visibility', visible = false })
        return
    end

    Wait(600)
    sendVehicleConfiguration()
    sendVehicleLayout(true)

    while true do
        local active = sendVehicleUpdate(false)
        Wait(active and Config.Vehicle.UpdateInterval or Config.Vehicle.IdleInterval)
    end
end)


CreateThread(function()
    while true do
        local vehicle = getCurrentVehicle()
        if vehicle ~= 0 then
            if vehicleState.seatbelt and isSeatbeltAvailable(vehicle) then
                DisableControlAction(0, 75, true)
            end

            if isDriver(vehicle) then
                DisableControlAction(0, 74, true)
                applyEngineState(vehicle)
                if vehicleState.engineOff and IsControlJustPressed(0, 71) then
                    local now = GetGameTimer()
                    if now - (vehicleState.lastEngineNotify or 0) >= 4000 then
                        vehicleState.lastEngineNotify = now
                        local seatbelt = Config.Vehicle.Seatbelt or {}
                        showEsxNotify(seatbelt.EngineOffMessage or 'Start the vehicle.')
                    end
                end
            end
            Wait(0)
        else
            Wait(350)
        end
    end
end)

CreateThread(function()
    local seatbelt = Config.Vehicle.Seatbelt or {}
    local remindEvery = math.max(2000, tonumber(seatbelt.ReminderInterval) or 5000)
    local retryEvery = math.max(500, tonumber(seatbelt.WarningInterval) or 1000)

    while true do
        Wait(250)
        local vehicle = getCurrentVehicle()
        local warn = needsSeatbeltWarning(vehicle)
        local now = GetGameTimer()

        if seatbelt.WarningChime ~= false and warn then
            -- Repeat the start request without restarting an already playing clip.
            -- This recovers if Chromium rejected or missed the first play request.
            if not vehicleState.chimeOn
                or now - (vehicleState.lastChimeRequest or 0) >= retryEvery then
                setSeatbeltChime(true, true)
            end
        else
            setSeatbeltChime(false)
        end

        if warn and now - (vehicleState.lastBeltNotify or 0) >= remindEvery then
            vehicleState.lastBeltNotify = now
            showEsxNotify(seatbelt.ReminderMessage or 'Fasten your seatbelt.')
        end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.Vehicle.LayoutCheckInterval)
        if vehicleState.vehicle ~= 0 then sendVehicleLayout(false) end
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    if vehicleState.vehicle ~= 0 then
        clearIndicators()
        if vehicleState.manualLights ~= nil and DoesEntityExist(vehicleState.vehicle) then
            SetVehicleLights(vehicleState.vehicle, 0)
        end
    end
    vehicleState.seatbelt = false
    vehicleState.manualLights = nil
    setSeatbeltChime(false, true)
    SendNUIMessage({ action = 'vehicle:visibility', visible = false })
end)

exports('IsSeatbeltOn', function()
    return vehicleState.seatbelt
end)
exports('GetVehicleTrip', function()
    return vehicleState.tripKm
end)
