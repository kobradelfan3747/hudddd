if not Config.Needs or not Config.Needs.Enabled or Config.Needs.UseExternalStatus then
    return
end


local ESX_MAX = 1000000.0

local needs = {
    hunger = Config.Needs.StartValue,
    thirst = Config.Needs.StartValue
}

local isLoaded    = false
local receivedServerNeeds = false
local lastDamage  = 0
local lastSave    = 0
local lastSyncedHunger = -1.0
local lastSyncedThirst = -1.0

local function debugPrint(_)
end

local function clampNeed(value)
    value = tonumber(value) or 0
    if value < 0 then return 0.0 end
    if value > 100 then return 100.0 end
    return value + 0.0
end

local function toPercent(value)
    value = tonumber(value) or 0

    if value > 100 then
        return (value / ESX_MAX) * 100.0
    end

    return value
end


local pending = {
    hunger = 0.0,
    thirst = 0.0
}

local function getNeed(name)
    return needs[name]
end

local function applyNeed(name, percent, silent)
    if needs[name] == nil then
        debugPrint(('unknown need: %s'):format(tostring(name)))
        return
    end

    local before = needs[name]
    needs[name]  = clampNeed(percent)

    if not silent and math.abs(before - needs[name]) > 0.01 then
        debugPrint(('%s: %.1f%% -> %.1f%%'):format(name, before, needs[name]))
    end

    return needs[name]
end

local function setNeed(name, percent, silent)
    if needs[name] == nil then
        debugPrint(('unknown need: %s'):format(tostring(name)))
        return
    end

    pending[name] = 0.0

    return applyNeed(name, percent, silent)
end

local function addNeed(name, percent)
    if needs[name] == nil then return end
    return applyNeed(name, needs[name] + (tonumber(percent) or 0))
end

local function removeNeed(name, percent)
    if needs[name] == nil then return end
    return applyNeed(name, needs[name] - (tonumber(percent) or 0))
end


local function gradualEnabled()
    return Config.Needs.Gradual and Config.Needs.Gradual.Enabled
end

local function queueNeed(name, percent)
    if needs[name] == nil then return end

    percent = tonumber(percent) or 0
    if percent <= 0 then return end

    if not gradualEnabled() then
        return addNeed(name, percent)
    end

    local maxQueued = Config.Needs.Gradual.MaxQueued or 100.0
    pending[name]   = math.min(pending[name] + percent, maxQueued)

    debugPrint(('queued %.1f%% for %s (total pending %.1f%%)'):format(percent, name, pending[name]))
end

CreateThread(function()
    if not gradualEnabled() then return end

    local step     = math.max(50, Config.Needs.Gradual.StepInterval or 100)
    local perSec   = Config.Needs.Gradual.FillPerSecond or 5.0
    local perStep  = perSec * (step / 1000.0)

    debugPrint(('gradual fill: %.2f%%/s (%.3f%% per %dms step)'):format(perSec, perStep, step))

    while true do
        Wait(step)

        for name, remaining in pairs(pending) do
            if remaining > 0 then
                local amount = math.min(remaining, perStep)

                if needs[name] >= 100.0 then
                    pending[name] = 0.0
                else
                    needs[name]   = clampNeed(needs[name] + amount)
                    pending[name] = math.max(0.0, remaining - amount)
                end
            end
        end
    end
end)

local function getPending(name)
    return pending[name] or 0.0
end


exports('getNeed', function(name)
    return getNeed(name)
end)

exports('getNeeds', function()
    return { hunger = needs.hunger, thirst = needs.thirst }
end)

exports('setNeed', function(name, percent)
    return setNeed(name, toPercent(percent))
end)

exports('addNeed', function(name, percent)
    return queueNeed(name, toPercent(percent))
end)

exports('addNeedInstant', function(name, percent)
    return addNeed(name, toPercent(percent))
end)

exports('getPendingNeed', function(name)
    return getPending(name)
end)

exports('removeNeed', function(name, percent)
    return removeNeed(name, toPercent(percent))
end)

exports('getStatus', function(name)
    local value = needs[name]
    if not value then return nil end

    return {
        name    = name,
        val     = (value / 100.0) * ESX_MAX,
        max     = ESX_MAX,
        percent = value,
        getPercent = function() return value end
    }
end)

exports('getPercent', function(name)
    return needs[name]
end)


if Config.Needs.ListenToESXEvents then

    RegisterNetEvent('esx_status:set')
    AddEventHandler('esx_status:set', function(name, value)
        setNeed(name, toPercent(value))
    end)

    RegisterNetEvent('esx_status:add')
    AddEventHandler('esx_status:add', function(name, value)

        queueNeed(name, toPercent(value))
    end)

    RegisterNetEvent('esx_status:remove')
    AddEventHandler('esx_status:remove', function(name, value)
        removeNeed(name, toPercent(value))
    end)

    RegisterNetEvent('esx_status:setPercent')
    AddEventHandler('esx_status:setPercent', function(name, percent)
        setNeed(name, tonumber(percent))
    end)

    RegisterNetEvent('esx_status:addPercent')
    AddEventHandler('esx_status:addPercent', function(name, percent)
        queueNeed(name, tonumber(percent))
    end)

    RegisterNetEvent('esx_status:removePercent')
    AddEventHandler('esx_status:removePercent', function(name, percent)
        removeNeed(name, tonumber(percent))
    end)

    AddEventHandler('esx_status:getStatus', function(name, callback)
        local value = needs[name]
        if not value or type(callback) ~= 'function' then return end

        callback({
            name    = name,
            val     = (value / 100.0) * ESX_MAX,
            max     = ESX_MAX,
            percent = value,
            getPercent = function() return value end
        })
    end)
end


RegisterNetEvent('vn-hud:client:setNeed')
AddEventHandler('vn-hud:client:setNeed', function(name, percent)
    setNeed(name, tonumber(percent))
end)

RegisterNetEvent('vn-hud:client:addNeed')
AddEventHandler('vn-hud:client:addNeed', function(name, percent)
    queueNeed(name, tonumber(percent))
end)

RegisterNetEvent('vn-hud:client:loadNeeds')
AddEventHandler('vn-hud:client:loadNeeds', function(data)
    if type(data) == 'table' then
        if tonumber(data.hunger) then
            needs.hunger = clampNeed(data.hunger)
        end
        if tonumber(data.thirst) then
            needs.thirst = clampNeed(data.thirst)
        end
    end

    pending.hunger = 0.0
    pending.thirst = 0.0

    isLoaded = true
    receivedServerNeeds = true
    lastSyncedHunger = needs.hunger
    lastSyncedThirst = needs.thirst
    debugPrint(('loaded: hunger=%.1f%% thirst=%.1f%%'):format(needs.hunger, needs.thirst))

    TriggerServerEvent('vn-hud:server:syncNeeds', {
        hunger = needs.hunger,
        thirst = needs.thirst
    })
end)


CreateThread(function()
    if not Config.Needs.SaveEnabled then
        isLoaded = true
        return
    end

    local attempts = 0

    while not isLoaded and attempts < 15 do
        Wait(attempts == 0 and 800 or 1500)

        if not isLoaded then
            attempts = attempts + 1
            debugPrint(('requesting needs from server (attempt %d)'):format(attempts))
            TriggerServerEvent('vn-hud:server:requestNeeds')
        end
    end

    if not isLoaded then
        isLoaded = true
        debugPrint('no answer from server, starting with default values (will not overwrite saved needs).')
    end
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function()
    if not Config.Needs.SaveEnabled then return end
    isLoaded = false
    receivedServerNeeds = false
    TriggerServerEvent('vn-hud:server:requestNeeds')
end)

AddEventHandler('esx:onPlayerLogout', function()
    if not Config.Needs.SaveEnabled then return end
    if receivedServerNeeds then
        TriggerServerEvent('vn-hud:server:saveNeeds', {
            hunger = needs.hunger,
            thirst = needs.thirst
        })
    end
    isLoaded = false
    receivedServerNeeds = false
end)

-- GTA reports a normal player's health as 100..200 while this HUD displays
-- that range as 0..100. Reaching the native base must therefore be lethal,
-- otherwise the health bar can remain near zero forever.
local PLAYER_HEALTH_BASE = 100

local function applyStarvationDamage(ped)
    local health = tonumber(GetEntityHealth(ped)) or 0
    if health <= 0 then return end

    local damage = math.max(1, math.floor(tonumber(Config.Needs.DamageAmount) or 1))
    local nextHealth = health - damage

    if Config.Needs.DamageCanKill ~= false then
        if nextHealth <= PLAYER_HEALTH_BASE then
            nextHealth = 0
        end
    else
        local minimum = math.max(0, math.floor(tonumber(Config.Needs.DamageMinHealth) or 105))
        if health <= minimum then return end
        nextHealth = math.max(minimum, nextHealth)
    end

    if nextHealth < health then
        SetEntityHealth(ped, nextHealth)
    end
end


CreateThread(function()

    local function ratePerSecond(minutes)
        minutes = tonumber(minutes) or 60
        if minutes <= 0 then return 0 end
        return 100.0 / (minutes * 60.0)
    end

    local hungerRate = ratePerSecond(Config.Needs.HungerMinutes)
    local thirstRate = ratePerSecond(Config.Needs.ThirstMinutes)

    local interval  = math.max(100, Config.Needs.TickInterval)
    local seconds   = interval / 1000.0

    debugPrint(('drain rates: hunger=%.4f%%/s thirst=%.4f%%/s'):format(hungerRate, thirstRate))

    while true do
        Wait(interval)

        local ped = PlayerPedId()

        if not IsEntityDead(ped) then

            local multiplier = 1.0

            if IsPedSprinting(ped) then
                multiplier = Config.Needs.SprintMultiplier or 1.0
            elseif IsPedSwimming(ped) then
                multiplier = Config.Needs.SwimMultiplier or 1.0
            elseif IsPedInAnyVehicle(ped, false) then
                multiplier = Config.Needs.VehicleMultiplier or 1.0
            end

            needs.hunger = clampNeed(needs.hunger - (hungerRate * seconds * multiplier))
            needs.thirst = clampNeed(needs.thirst - (thirstRate * seconds * multiplier))

            if Config.Needs.DamageEnabled then
                local threshold = Config.Needs.DamageThreshold or 0
                local starving = needs.hunger <= threshold or needs.thirst <= threshold
                local now = GetGameTimer()

                if starving then
                    if lastDamage == 0 then
                        lastDamage = now
                    elseif now - lastDamage >= (Config.Needs.DamageInterval or 5000) then
                        lastDamage = now

                        applyStarvationDamage(ped)
                    end
                else
                    lastDamage = 0
                end
            end
        end
    end
end)


local SYNC_INTERVAL = math.max(2000, Config.Needs.SyncInterval or 10000)

local lastSyncedHunger = -1.0
local lastSyncedThirst = -1.0

local function syncToServer(force)
    if not isLoaded then return end
    if not Config.Needs.SaveEnabled then return end

    if not force
        and math.abs(needs.hunger - lastSyncedHunger) < 0.05
        and math.abs(needs.thirst - lastSyncedThirst) < 0.05 then
        return
    end

    lastSyncedHunger = needs.hunger
    lastSyncedThirst = needs.thirst

    TriggerServerEvent('vn-hud:server:syncNeeds', {
        hunger = needs.hunger,
        thirst = needs.thirst
    })
end

CreateThread(function()
    if not Config.Needs.SaveEnabled then return end

    debugPrint(('sync to server every %d ms'):format(SYNC_INTERVAL))

    while true do
        Wait(SYNC_INTERVAL)
        syncToServer(false)
    end
end)

CreateThread(function()
    if not Config.Needs.SaveEnabled then return end

    local interval = math.max(10000, Config.Needs.SaveInterval or 30000)

    while true do
        Wait(interval)

        if isLoaded and receivedServerNeeds then
            TriggerServerEvent('vn-hud:server:saveNeeds', {
                hunger = needs.hunger,
                thirst = needs.thirst
            })
            debugPrint(('sent to server: hunger=%.1f%% thirst=%.1f%%'):format(needs.hunger, needs.thirst))
        end
    end
end)

CreateThread(function()
    if not Config.Needs.SaveEnabled then return end

    local wasPause = false
    while true do
        Wait(400)
        local pause = IsPauseMenuActive()
        if pause and not wasPause and receivedServerNeeds then
            syncToServer(true)
            TriggerServerEvent('vn-hud:server:saveNeeds', {
                hunger = needs.hunger,
                thirst = needs.thirst
            })
        end
        wasPause = pause
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if not Config.Needs.SaveEnabled then return end
    if not receivedServerNeeds then return end

    TriggerServerEvent('vn-hud:server:saveNeeds', {
        hunger = needs.hunger,
        thirst = needs.thirst
    })
end)

AddEventHandler('playerSpawned', function()
    if not Config.Needs.SaveEnabled then return end
    if not receivedServerNeeds then
        TriggerServerEvent('vn-hud:server:requestNeeds')
    end
end)


CreateThread(function()
    if not Config.Needs.Debug then return end

    RegisterCommand('needs', function()
    end, false)
end)

local isConsuming = false

local function playConsumeSound(kind, ped)
    local sounds = Config.Needs.Sounds
    if not sounds or sounds.Enabled == false then
        return
    end

    local setup = (kind == 'drink') and (sounds.Drink or {}) or (sounds.Eat or {})
    if type(setup.Bank) == 'string' and setup.Bank ~= '' then
        pcall(RequestAmbientAudioBank, setup.Bank, false)
        pcall(RequestScriptAudioBank, setup.Bank, false)
    end

    if type(setup.Name) == 'string' and setup.Name ~= '' then
        local setName = setup.Set or 'HUD_FRONTEND_DEFAULT_SOUNDSET'
        PlaySoundFrontend(-1, setup.Name, setName, true)
        PlaySoundFromEntity(-1, setup.Name, ped, setName, false, 0)
    end

    if kind == 'drink' then
        PlaySoundFromEntity(-1, 'Michael_Swallow', ped, 'FAMILY_5_SOUNDS', false, 0)
    end

    if type(setup.Speech) == 'string' and setup.Speech ~= '' then
        pcall(PlayPedAmbientSpeechNative, ped, setup.Speech, 'SPEECH_PARAMS_FORCE_NORMAL')
    end
end

local function playConsumeAnimation(kind)
    if not (Config.Needs.Animation and Config.Needs.Animation.Enabled) then
        playConsumeSound(kind, PlayerPedId())
        SendNUIMessage({ action = 'needs:sound', kind = kind })
        return
    end
    if isConsuming then return end

    isConsuming = true

    CreateThread(function()
        local ped      = PlayerPedId()
        local duration = Config.Needs.Animation.Duration or 3000
        local sounds = Config.Needs.Sounds or {}
        local setup = (kind == 'drink') and (sounds.Drink or {}) or (sounds.Eat or {})
        local soundEvery = math.max(350, tonumber(setup.Interval) or 700)

        local dict  = 'mp_player_intdrink'
        local anim  = 'loop_bottle'
        local prop  = 'prop_ld_flow_bottle'

        if kind == 'food' then
            dict = 'mp_player_inteat@burger'
            anim = 'mp_player_int_eat_burger'
            prop = 'prop_cs_burger_01'
        end

        RequestAnimDict(dict)

        local waited = 0
        while not HasAnimDictLoaded(dict) and waited < 2000 do
            Wait(50)
            waited = waited + 50
        end

        local propObject = nil
        local model      = GetHashKey(prop)

        RequestModel(model)
        waited = 0
        while not HasModelLoaded(model) and waited < 2000 do
            Wait(50)
            waited = waited + 50
        end

        if HasModelLoaded(model) then
            local coords = GetEntityCoords(ped)
            propObject = CreateObject(model, coords.x, coords.y, coords.z + 0.2, true, true, true)

            AttachEntityToEntity(
                propObject, ped,
                GetPedBoneIndex(ped, 18905),
                0.12, 0.028, 0.001,
                10.0, 175.0, 0.0,
                true, true, false, true, 1, true
            )
        end

        if HasAnimDictLoaded(dict) then
            TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, 49, 0, false, false, false)
        end

        local elapsed = 0
        playConsumeSound(kind, ped)
        SendNUIMessage({ action = 'needs:sound', kind = kind })
        while elapsed < duration do
            local step = math.min(soundEvery, duration - elapsed)
            Wait(step)
            elapsed = elapsed + step
            if elapsed < duration then
                local livePed = PlayerPedId()
                playConsumeSound(kind, livePed)
                SendNUIMessage({ action = 'needs:sound', kind = kind })
            end
        end

        ClearPedTasks(PlayerPedId())

        if propObject then
            DeleteEntity(propObject)
        end

        SetModelAsNoLongerNeeded(model)
        RemoveAnimDict(dict)

        isConsuming = false
    end)
end


RegisterNetEvent('vn-hud:client:consume')
AddEventHandler('vn-hud:client:consume', function(kind, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return end

    local needName = (kind == 'drink') and 'thirst' or 'hunger'
    local multiplier = (kind == 'drink')
        and (tonumber(Config.Needs.DrinkMultiplier) or 1.0)
        or (tonumber(Config.Needs.FoodMultiplier) or 1.0)

    playConsumeAnimation(kind == 'drink' and 'drink' or 'food')

    queueNeed(needName, amount * multiplier)

    if receivedServerNeeds then
        syncToServer(true)
    end

    if Config.Needs.Notify and Config.Needs.Notify.Enabled then
        local message = (kind == 'drink')
            and (Config.Needs.Notify.DrinkMessage or 'Drinking...')
            or  (Config.Needs.Notify.EatMessage   or 'Eating...')

        local sent = pcall(function()
            TriggerEvent('vn-hud:client:notify', message)
        end)

        if not sent then
            BeginTextCommandThefeedPost('STRING')
            AddTextComponentSubstringPlayerName(message)
            EndTextCommandThefeedPostTicker(false, true)
        end
    end
end)


CreateThread(function()
    if not Config.Needs.Debug then return end

    RegisterCommand('testeat', function(_, args)
        local amount = tonumber(args[1]) or 25
        TriggerEvent('vn-hud:client:consume', 'food', amount)
    end, false)

    RegisterCommand('testdrink', function(_, args)
        local amount = tonumber(args[1]) or 30
        TriggerEvent('vn-hud:client:consume', 'drink', amount)
    end, false)
end)
