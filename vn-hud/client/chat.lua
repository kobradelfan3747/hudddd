local chatOpen = false
local chatInputActivating = false
local suggestions = {}
local threeDMessages = {}
local lastHudChat = { key = '', at = 0 }

local function trim(value)
    if type(value) ~= 'string' then
        return ''
    end

    return value:match('^%s*(.-)%s*$') or ''
end

local function setChatOpen(open, deferFocus)
    open = open == true
    if chatOpen == open then
        return
    end

    chatOpen = open
    chatInputActivating = open and deferFocus == true

    if not chatInputActivating then
        SetNuiFocus(open, open)
        SetNuiFocusKeepInput(false)
    end

    SendNUIMessage({
        action = open and 'chat:open' or 'chat:close'
    })
end

local function addMessage(message)
    if type(message) == 'string' then
        message = { args = { message } }
    end

    if type(message) ~= 'table' then
        return
    end

    local parts = {}
    if type(message.args) == 'table' then
        for index = 1, #message.args do
            parts[#parts + 1] = tostring(message.args[index] or '')
        end
    end
    local key = table.concat({
        tostring(message.tag or ''),
        tostring(message.author or ''),
        table.concat(parts, '\n'),
        tostring(message.text or message.message or '')
    }, '|')
    local now = GetGameTimer()
    if key ~= '|||' and key == lastHudChat.key and (now - lastHudChat.at) < 600 then
        return
    end
    lastHudChat.key = key
    lastHudChat.at = now

    SendNUIMessage({
        action = 'chat:addMessage',
        message = message
    })
end

local function addSuggestion(name, help, params)
    if type(name) ~= 'string' or name == '' then
        return
    end

    suggestions[name] = {
        name = name,
        help = '',
        params = params or {}
    }

    SendNUIMessage({
        action = 'chat:addSuggestion',
        suggestion = suggestions[name]
    })
end

local function refreshCommands()
    if not GetRegisteredCommands then return end

    for _, command in ipairs(GetRegisteredCommands()) do
        if command.name ~= 'toggleChat' and command.name ~= '+vnhudchat' and command.name ~= '-vnhudchat' then
            local commandName = '/' .. command.name
            if IsAceAllowed(('command.%s'):format(command.name)) then
                addSuggestion(commandName, '', nil)
            end
        end
    end
end

local function sendChatConfiguration()
    SendNUIMessage({
        action = 'chat:configure',
        config = {
            maxMessages = Config.Chat.MaxMessages,
            maxLength = Config.Chat.MaxMessageLength,
            fadeAfter = Config.Chat.FadeAfter,
            timeOffsetHours = Config.Chat.TimeOffsetHours,
            accent = Config.Chat.AccentColor,
            position = Config.Chat.Position
        }
    })
end

RegisterNetEvent('chatMessage')
AddEventHandler('chatMessage', function(author, color, text)
    local args = { text or '' }
    if type(author) == 'string' and author ~= '' then
        table.insert(args, 1, author)
    end

    addMessage({
        color = color,
        multiline = true,
        args = args
    })
end)

RegisterNetEvent('chat:addMessage')
AddEventHandler('chat:addMessage', addMessage)

RegisterNetEvent('vn-hud:client:chatMessage')
AddEventHandler('vn-hud:client:chatMessage', addMessage)

RegisterNetEvent('chat:addSuggestion')
AddEventHandler('chat:addSuggestion', addSuggestion)

RegisterNetEvent('chat:addSuggestions')
AddEventHandler('chat:addSuggestions', function(items)
    if type(items) ~= 'table' then
        return
    end

    for _, suggestion in ipairs(items) do
        if type(suggestion) == 'table' then
            addSuggestion(suggestion.name, suggestion.help, suggestion.params)
        end
    end
end)

RegisterNetEvent('chat:removeSuggestion')
AddEventHandler('chat:removeSuggestion', function(name)
    suggestions[name] = nil
    SendNUIMessage({ action = 'chat:removeSuggestion', name = name })
end)

RegisterNetEvent('chat:clear')
AddEventHandler('chat:clear', function()
    SendNUIMessage({ action = 'chat:clear' })
end)


RegisterNetEvent('chat:addTemplate')
RegisterNetEvent('chat:addMode')
RegisterNetEvent('chat:removeMode')

RegisterNUICallback('vnChatSubmit', function(data, cb)
    local message = trim(data and data.message)
    setChatOpen(false)

    if message ~= '' then
        if #message > Config.Chat.MaxMessageLength then
            message = message:sub(1, Config.Chat.MaxMessageLength)
        end

        if message:sub(1, 1) == '/' then
            local body = message:sub(2)
            local cmd, rest = body:match('^(%S+)%s*(.*)$')
            cmd = cmd and string.lower(cmd) or ''
            if cmd == 'a' or cmd == 'f' or cmd == 'dep' then
                TriggerServerEvent('vn-hud:server:modeChat', cmd, rest or '')
            else
                ExecuteCommand(body)
            end
        else
            TriggerServerEvent('vn-hud:server:chatMessage', message)
        end
    end

    cb({ ok = true })
end)

RegisterNUICallback('vnChatClose', function(_, cb)
    setChatOpen(false)
    cb({ ok = true })
end)

RegisterNUICallback('vnChatReady', function(_, cb)
    sendChatConfiguration()
    refreshCommands()

    for _, suggestion in pairs(suggestions) do
        SendNUIMessage({ action = 'chat:addSuggestion', suggestion = suggestion })
    end

    if chatOpen then SendNUIMessage({ action = 'chat:open' }) end
    cb({ ok = true })
end)

exports('AddChatMessage', addMessage)
exports('AddChatSuggestion', addSuggestion)
exports('OpenChat', function()
    if Config.Chat.Enabled then
        setChatOpen(true)
    end
end)

RegisterNetEvent('vn-hud:client:show3DText', function(data)
    if type(data) ~= 'table' or not tonumber(data.serverId) or type(data.text) ~= 'string' then
        return
    end

    threeDMessages[#threeDMessages + 1] = {
        serverId = tonumber(data.serverId),
        author = tostring(data.author or ''),
        text = data.text,
        tag = tostring(data.tag or data.mode or 'RP'),
        color = type(data.color) == 'table' and data.color or Config.Chat.SystemColor,
        maxDistance = tonumber(data.maxDistance) or Config.Chat.ThreeDDistance,
        expiresAt = GetGameTimer() + (tonumber(data.duration) or Config.Chat.ThreeDDuration)
    }
end)

local function draw3DText(coords, text, color, verticalOffset)
    local visible, screenX, screenY = World3dToScreen2d(coords.x, coords.y, coords.z + verticalOffset)
    if not visible then return end

    SetTextScale(0.0, 0.31)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextCentre(true)
    SetTextColour(
        tonumber(color[1]) or 255,
        tonumber(color[2]) or 255,
        tonumber(color[3]) or 255,
        235
    )
    SetTextDropshadow(1, 0, 0, 0, 220)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(screenX, screenY)
end

CreateThread(function()
    while true do
        if #threeDMessages == 0 then
            Wait(250)
        else
            Wait(0)
            local now = GetGameTimer()
            local localCoords = GetEntityCoords(PlayerPedId())
            local stackByPlayer = {}

            for index = #threeDMessages, 1, -1 do
                local message = threeDMessages[index]
                if now >= message.expiresAt then
                    table.remove(threeDMessages, index)
                else
                    local player = GetPlayerFromServerId(message.serverId)
                    if player ~= -1 then
                        local ped = GetPlayerPed(player)
                        if ped and ped ~= 0 then
                            local coords = GetEntityCoords(ped)
                            local dx, dy, dz = localCoords.x - coords.x, localCoords.y - coords.y, localCoords.z - coords.z
                            local distance = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))

                            if distance <= message.maxDistance then
                                local stack = stackByPlayer[message.serverId] or 0
                                stackByPlayer[message.serverId] = stack + 1
                                local tag = tostring(message.tag or '')
                                local label
                                if tag == 'ME' or tag == 'DO' then
                                    label = ('[%s] %s : %s'):format(tag, message.author, message.text)
                                else
                                    label = ('[%s] %s %s'):format(tag, message.author, message.text)
                                end
                                draw3DText(coords, label, message.color, 1.05 + (stack * 0.16))
                            end
                        end
                    end
                end
            end
        end
    end
end)

CreateThread(function()
    if not Config.Chat.Enabled then
        return
    end

    SetTextChatEnabled(false)
    SetNuiFocus(false, false)

    sendChatConfiguration()

    Wait(500)
    refreshCommands()
    TriggerServerEvent('chat:init')

    local lastTextChatDisable = GetGameTimer()

    while true do
        Wait(0)

        if GetGameTimer() - lastTextChatDisable >= 5000 then
            SetTextChatEnabled(false)
            lastTextChatDisable = GetGameTimer()
        end


        DisableControlAction(0, Config.Chat.OpenControl, true)

        if not chatOpen and IsDisabledControlJustPressed(0, Config.Chat.OpenControl) then
            if not IsPauseMenuActive() and not IsScreenFadedOut() then

                setChatOpen(true, true)
            end
        end

        if chatInputActivating and not IsDisabledControlPressed(0, Config.Chat.OpenControl) then
            chatInputActivating = false
            SetNuiFocus(true, true)
            SetNuiFocusKeepInput(false)
        end

        if chatOpen and (IsPauseMenuActive() or IsScreenFadedOut()) then
            setChatOpen(false)
        end
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        Wait(250)
        refreshCommands()
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        chatOpen = false
        SetNuiFocus(false, false)
        SetTextChatEnabled(true)
    end
end)
