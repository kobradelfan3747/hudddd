local radioTalking = false
local forcedModeIndex = nil
local lastPayloadKey = nil
local testTalkingUntil = 0

local function sendVoiceConfiguration()
    SendNUIMessage({
        action = 'voice:configure',
        config = {
            sizeVh = Config.Voice.SizeVh,
            offsetRightVw = Config.Voice.OffsetRightVw,
            offsetBottomVh = Config.Voice.OffsetBottomVh,
            accent = Config.Voice.AccentColor,
            radioColor = Config.Voice.RadioColor
        }
    })
end

local function getVoiceState()
    local playerState = LocalPlayer and LocalPlayer.state or nil
    local proximity = playerState and playerState.proximity or nil
    local distance = nil
    local mode = nil
    local modeIndex = forcedModeIndex

    if type(proximity) == 'table' then
        distance = tonumber(proximity.distance or proximity.range or proximity[1])
        mode = proximity.mode or proximity.name
        modeIndex = tonumber(proximity.index or proximity.modeIndex) or modeIndex
    elseif tonumber(proximity) then
        distance = tonumber(proximity)
    end

    if type(mode) ~= 'string' or mode == '' then
        if modeIndex == 1 then
            mode = 'WHISPER'
        elseif modeIndex == 3 then
            mode = 'SHOUT'
        elseif distance then
            if distance <= Config.Voice.WhisperDistance then
                mode = 'WHISPER'
            elseif distance <= Config.Voice.NormalDistance then
                mode = 'NORMAL'
            else
                mode = 'SHOUT'
            end
        else
            mode = 'NORMAL'
        end
    end

    local stateRadio = playerState and (
        playerState.radioActive == true
        or playerState.talkingOnRadio == true
        or playerState.isTalkingOnRadio == true
    ) or false
    local isRadio = radioTalking or stateRadio

    local stateTalking = playerState and (
        playerState.isTalking == true
        or playerState.talking == true
    ) or false

    local networkTalking = NetworkIsPlayerTalking(PlayerId()) == true
    local mumbleTalking = false
    if MumbleIsPlayerTalking then
        local ok, result = pcall(MumbleIsPlayerTalking, PlayerId())
        mumbleTalking = ok and (result == true or result == 1)
    end

    local pushToTalk = false
    if Config.Voice.UsePushToTalkFallback and Config.Voice.PushToTalkControl then
        pushToTalk = IsControlPressed(0, Config.Voice.PushToTalkControl)
            or IsDisabledControlPressed(0, Config.Voice.PushToTalkControl)
    end

    local debugTalking = GetGameTimer() < testTalkingUntil
    local talking = networkTalking or mumbleTalking or stateTalking or isRadio or pushToTalk or debugTalking

    local muted = playerState and (
        playerState.muted == true
        or playerState.voiceMuted == true
        or playerState.isMuted == true
    ) or false

    if muted then
        talking = false
        mode = 'MUTED'
    elseif isRadio then
        mode = 'RADIO'
    end

    local visible = Config.Voice.Enabled
        and (Config.Voice.ShowWhenIdle or talking)
        and (not Config.Voice.HideOnPause or not IsPauseMenuActive())

    return {
        talking = talking,
        radio = isRadio,
        muted = muted,
        mode = string.upper(tostring(mode)),
        distance = distance or 0.0,
        visible = visible
    }
end

local function sendVoiceState(force)
    local payload = getVoiceState()
    local key = ('%s:%s:%s:%s:%.2f'):format(
        tostring(payload.talking),
        tostring(payload.radio),
        tostring(payload.visible),
        payload.mode,
        payload.distance
    )

    if not force and key == lastPayloadKey then return payload.talking end
    lastPayloadKey = key

    payload.action = 'voice:update'
    SendNUIMessage(payload)
    return payload.talking
end

AddEventHandler('pma-voice:radioActive', function(active)
    radioTalking = active == true
    sendVoiceState(true)
end)

AddEventHandler('pma-voice:setTalkingMode', function(mode)
    forcedModeIndex = tonumber(mode)
    sendVoiceState(true)
end)

RegisterNetEvent('vn-hud:client:setRadioTalking', function(active)
    radioTalking = active == true
    sendVoiceState(true)
end)


RegisterCommand('vntestvoice', function()
    testTalkingUntil = GetGameTimer() + 5000
    sendVoiceState(true)
end, false)

RegisterNUICallback('vnVoiceReady', function(_, callback)
    sendVoiceConfiguration()
    sendVoiceState(true)
    callback({ ok = true })
end)

CreateThread(function()
    if not Config.Voice.Enabled then
        SendNUIMessage({ action = 'voice:update', visible = false })
        return
    end

    Wait(500)
    sendVoiceConfiguration()
    sendVoiceState(true)

    while true do
        local talking = sendVoiceState(false)
        Wait(talking and Config.Voice.UpdateInterval or Config.Voice.IdleUpdateInterval)
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SendNUIMessage({ action = 'voice:update', visible = false })
    end
end)
