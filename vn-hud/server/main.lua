local RESOURCE_NAME = GetCurrentResourceName()
local STAFF_CHAT_ACE = 'vn_hud.adminchat'
local ESX = nil
local profileCache = {}
local sqlIdentity = {}
local trustedGroupCache = {}
local chatSpamState = {}
local lastPrivateTarget = {}
local playerJobCache = {}
local gradeBook = {}
local gradeBookTried = false
local chatDisplayName

local function debugPrint(_)
end

local function getESX()
    if ESX then return ESX end
    if GetResourceState('es_extended') ~= 'started' then return nil end

    local ok, object = pcall(function()
        return exports['es_extended']:getSharedObject()
    end)

    if ok and object then
        ESX = object
    else
        TriggerEvent('esx:getSharedObject', function(sharedObject)
            ESX = sharedObject
        end)
    end

    return ESX
end

local function cleanPart(value)
    if value == nil then return '' end
    return tostring(value):gsub('^%s+', ''):gsub('%s+$', '')
end

local function rememberTrustedGroup(source, group, authoritative)
    source = tonumber(source) or source
    group = string.lower(cleanPart(group))
    if not source or group == '' then return end

    local current = trustedGroupCache[source]
    if type(current) == 'table' and current.authoritative and not authoritative then
        return
    end

    trustedGroupCache[source] = {
        group = group,
        authoritative = authoritative == true
    }
end

local function readTrustedGroup(source)
    local cached = trustedGroupCache[tonumber(source) or source]
    if type(cached) == 'table' then
        return cached.group, cached.authoritative == true
    end
    if type(cached) == 'string' then
        return cached, false
    end
    return nil, false
end

local function joinName(firstName, lastName)
    return (('%s %s'):format(cleanPart(firstName), cleanPart(lastName)))
        :gsub('^%s+', '')
        :gsub('%s+$', '')
end

local function getXPlayer(source)
    local sharedObject = getESX()
    if not sharedObject then return nil end

    if type(sharedObject.GetPlayerFromId) == 'function' then
        local ok, player = pcall(sharedObject.GetPlayerFromId, source)
        if ok and player then return player end

        ok, player = pcall(sharedObject.GetPlayerFromId, sharedObject, source)
        if ok and player then return player end
    end

    if type(sharedObject.Players) == 'table' then
        return sharedObject.Players[tonumber(source)] or sharedObject.Players[tostring(source)]
    end

    return nil
end

local function addIdentifier(list, seen, value)
    value = cleanPart(value)
    if value == '' then return end

    local current = value
    for _ = 1, 3 do
        if not seen[current] then
            seen[current] = true
            list[#list + 1] = current
        end

        local stripped = current:gsub('^[^:]+:', '')
        if stripped == current then break end
        current = stripped
    end
end

local function getIdentifierCandidates(source, xPlayer)
    local candidates, seen = {}, {}

    if xPlayer then
        if type(xPlayer.getIdentifier) == 'function' then
            local ok, identifier = pcall(xPlayer.getIdentifier)
            if ok then addIdentifier(candidates, seen, identifier) end
        end
        addIdentifier(candidates, seen, xPlayer.identifier)

        if type(xPlayer.get) == 'function' then
            local ok, identifier = pcall(xPlayer.get, 'identifier')
            if ok then addIdentifier(candidates, seen, identifier) end
        end
    end

    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        addIdentifier(candidates, seen, identifier)
        local kind = identifier:match('^([^:]+):')
        if kind == 'license' or kind == 'license2' or kind == 'steam' then
            addIdentifier(candidates, seen, 'char1:' .. identifier)
            addIdentifier(candidates, seen, 'char2:' .. identifier)
            addIdentifier(candidates, seen, 'char3:' .. identifier)
        end
    end

    return candidates
end

local function getXPlayerAccount(xPlayer, accountName)
    if not xPlayer then return nil end

    if type(xPlayer.getAccount) == 'function' then
        local ok, account = pcall(xPlayer.getAccount, accountName)
        if ok and type(account) == 'table' then
            return math.floor(tonumber(account.money or account.amount or account.value) or 0)
        end
    end

    local accounts = nil
    if type(xPlayer.getAccounts) == 'function' then
        local ok, result = pcall(xPlayer.getAccounts)
        if ok and type(result) == 'table' then accounts = result end
    end
    if not accounts and type(xPlayer.accounts) == 'table' then accounts = xPlayer.accounts end

    if type(accounts) == 'table' then
        local direct = accounts[accountName]
        if direct ~= nil then
            if type(direct) == 'table' then
                return math.floor(tonumber(direct.money or direct.amount or direct.value) or 0)
            elseif tonumber(direct) ~= nil then
                return math.floor(tonumber(direct))
            end
        end

        for _, account in pairs(accounts) do
            if type(account) == 'table' and (account.name == accountName or account.account == accountName) then
                return math.floor(tonumber(account.money or account.amount or account.value) or 0)
            end
        end
    end

    if accountName == 'money' and type(xPlayer.getMoney) == 'function' then
        local ok, money = pcall(xPlayer.getMoney)
        if ok and tonumber(money) ~= nil then return math.floor(tonumber(money)) end
    end

    return nil
end

local function getFallbackProfile(source, xPlayer)
    local firstName, lastName = '', ''

    if xPlayer and type(xPlayer.get) == 'function' then
        local okFirst, valueFirst = pcall(xPlayer.get, 'firstName')
        local okLast, valueLast = pcall(xPlayer.get, 'lastName')
        if okFirst then firstName = cleanPart(valueFirst) end
        if okLast then lastName = cleanPart(valueLast) end
    end

    local fullName = joinName(firstName, lastName)
    if fullName == '' and xPlayer and type(xPlayer.getName) == 'function' then
        local ok, name = pcall(xPlayer.getName)
        if ok then fullName = cleanPart(name) end
    end
    if fullName == '' then fullName = GetPlayerName(source) or 'Player' end

    local group = 'user'
    if xPlayer and type(xPlayer.getGroup) == 'function' then
        local ok, value = pcall(xPlayer.getGroup)
        if ok and value then group = tostring(value) end
    elseif xPlayer and xPlayer.group then
        group = tostring(xPlayer.group)
    end

    return {
        fullName = fullName,
        firstName = firstName,
        lastName = lastName,
        cash = getXPlayerAccount(xPlayer, 'money') or 0,
        bank = getXPlayerAccount(xPlayer, 'bank') or 0,
        group = group,
        fromDatabase = false
    }
end

local function getLiveGroupCandidates(xPlayer)
    local groups, seen = {}, {}
    if not xPlayer then return groups end

    local function add(value)
        local group = string.lower(cleanPart(value))
        if group ~= '' and not seen[group] then
            seen[group] = true
            groups[#groups + 1] = group
        end
    end

    if type(xPlayer.getGroup) == 'function' then
        local ok, value = pcall(xPlayer.getGroup)
        if ok then add(value) end

        ok, value = pcall(xPlayer.getGroup, xPlayer)
        if ok then add(value) end
    end

    if type(xPlayer.get) == 'function' then
        local ok, value = pcall(xPlayer.get, 'group')
        if ok then add(value) end

        ok, value = pcall(xPlayer.get, xPlayer, 'group')
        if ok then add(value) end
    end

    if type(xPlayer.variables) == 'table' then
        add(xPlayer.variables.group)
    end
    add(xPlayer.group)

    return groups
end

local function getLiveGroup(xPlayer)
    return getLiveGroupCandidates(xPlayer)[1]
end

local function getXPlayerField(xPlayer, keys)
    if not xPlayer then return nil end

    if type(xPlayer.get) == 'function' then
        for _, key in ipairs(keys) do
            local ok, value = pcall(xPlayer.get, key)
            if ok and cleanPart(value) ~= '' then return value end
        end
    end

    if type(xPlayer.variables) == 'table' then
        for _, key in ipairs(keys) do
            local value = xPlayer.variables[key]
            if cleanPart(value) ~= '' then return value end
        end
    end

    for _, key in ipairs(keys) do
        local value = xPlayer[key]
        if cleanPart(value) ~= '' then return value end
    end

    return nil
end


local function rememberSqlIdentity(source, firstName, lastName)
    source = tonumber(source)
    firstName = cleanPart(firstName)
    lastName = cleanPart(lastName)
    local fullName = joinName(firstName, lastName)
    if not source or fullName == '' then
        return nil
    end

    sqlIdentity[source] = {
        firstName = firstName,
        lastName = lastName,
        fullName = fullName
    }
    return sqlIdentity[source]
end

local function applyRuntimeIdentity(source, profile)
    profile = type(profile) == 'table' and profile or {}
    local xPlayer = getXPlayer(source)
    local remembered = sqlIdentity[tonumber(source)]

    local firstName = ''
    local lastName = ''
    if remembered then
        firstName = cleanPart(remembered.firstName)
        lastName = cleanPart(remembered.lastName)
    end

    if firstName == '' and lastName == '' then
        firstName = cleanPart(profile.firstName or profile.firstname)
        lastName = cleanPart(profile.lastName or profile.lastname)
        if profile.fromDatabase == true then
            rememberSqlIdentity(source, firstName, lastName)
        end
    end

    if firstName == '' and lastName == '' then
        firstName = cleanPart(getXPlayerField(xPlayer, { 'firstName', 'firstname', 'first_name' }))
        lastName = cleanPart(getXPlayerField(xPlayer, { 'lastName', 'lastname', 'last_name' }))
    end

    local fullName = joinName(firstName, lastName)
    if fullName == '' then
        fullName = cleanPart(profile.fullName)
    end
    if fullName == '' then
        fullName = GetPlayerName(source) or 'Player'
    end

    profile.firstName = firstName
    profile.lastName = lastName
    profile.fullName = fullName
    profile.firstname = firstName
    profile.lastname = lastName
    profile.cash = getXPlayerAccount(xPlayer, 'money') or tonumber(profile.cash) or 0
    profile.bank = getXPlayerAccount(xPlayer, 'bank') or tonumber(profile.bank) or 0

    local liveGroup = getLiveGroup(xPlayer)
    if liveGroup then
        profile.group = liveGroup
    elseif cleanPart(profile.group) == '' then
        profile.group = 'user'
    end

    rememberTrustedGroup(source, profile.databaseGroup or profile.group, false)

    if remembered or profile.fromDatabase == true then
        profile.fromIdentity = true
    end

    return profile
end

local function decodeAccounts(value)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return {} end

    local ok, accounts = pcall(json.decode, value)
    return ok and type(accounts) == 'table' and accounts or {}
end

local function validSqlIdentifier(value)
    return type(value) == 'string' and value:match('^[%w_]+$') ~= nil
end

local function cacheProfile(candidates, profile)
    if not Config.Identity.Cache then return end
    for _, identifier in ipairs(candidates) do
        profileCache[identifier] = profile
    end
end

local function resolveProfile(source, callback, forceRefresh)
    local xPlayer = getXPlayer(source)
    local candidates = getIdentifierCandidates(source, xPlayer)

    if not Config.Identity.Enabled or #candidates == 0 then
        callback(applyRuntimeIdentity(source, getFallbackProfile(source, xPlayer)))
        return
    end

    if Config.Identity.Cache and not forceRefresh then
        for _, identifier in ipairs(candidates) do
            local cached = profileCache[identifier]
            if type(cached) == 'table' and cached.fromDatabase == true then
                local profile = applyRuntimeIdentity(source, cached)
                cacheProfile(candidates, profile)
                callback(profile)
                return
            end
        end
    end

    local columns = {
        Config.Identity.IdentifierColumn,
        Config.Identity.FirstNameColumn,
        Config.Identity.LastNameColumn,
        Config.Identity.GroupColumn
    }

    if GetResourceState('oxmysql') ~= 'started' or not validSqlIdentifier(Config.Identity.Table) then
        debugPrint('oxmysql is not started or the SQL table is invalid; using ESX fallback.')
        callback(applyRuntimeIdentity(source, getFallbackProfile(source, xPlayer)))
        return
    end

    for _, column in ipairs(columns) do
        if not validSqlIdentifier(column) then
            debugPrint(('Invalid SQL profile column: %s'):format(tostring(column)))
            callback(applyRuntimeIdentity(source, getFallbackProfile(source, xPlayer)))
            return
        end
    end

    local completed = false

    local function finish(profile)
        if completed then return end
        completed = true
        profile = applyRuntimeIdentity(source, profile)
        if profile.fromDatabase == true then
            cacheProfile(candidates, profile)
        end
        callback(profile)
    end

    local function finishFallback(reason)
        debugPrint(reason)
        finish(getFallbackProfile(source, xPlayer))
    end

    local function firstRow(rows)
        if type(rows) ~= 'table' then
            return nil
        end

        local firstCol = Config.Identity.FirstNameColumn
        local lastCol = Config.Identity.LastNameColumn
        if rows[firstCol] ~= nil or rows[lastCol] ~= nil or rows.firstname ~= nil or rows.lastname ~= nil then
            return rows
        end

        local row = rows[1]
        if type(row) == 'table' then
            return row
        end

        return nil
    end

    local function profileFromRow(row)
        local accounts = decodeAccounts(row[Config.Identity.AccountsColumn])
        local firstName = cleanPart(row[Config.Identity.FirstNameColumn] or row.firstname or row.firstName)
        local lastName = cleanPart(row[Config.Identity.LastNameColumn] or row.lastname or row.lastName)
        local databaseGroup = cleanPart(row[Config.Identity.GroupColumn])
        if databaseGroup == '' then databaseGroup = 'user' end
        local fullName = joinName(firstName, lastName)
        rememberSqlIdentity(source, firstName, lastName)
        if fullName == '' then fullName = getFallbackProfile(source, xPlayer).fullName end

        return {
            fullName = fullName,
            firstName = firstName,
            lastName = lastName,
            firstname = firstName,
            lastname = lastName,
            cash = math.floor(tonumber(accounts.money or accounts.cash) or 0),
            bank = math.floor(tonumber(accounts.bank) or 0),
            group = databaseGroup,
            databaseGroup = databaseGroup,
            fromDatabase = firstName ~= '' or lastName ~= ''
        }
    end

    local selectColumns = ('`%s`, `%s`, `%s`, `%s`'):format(
        Config.Identity.IdentifierColumn,
        Config.Identity.FirstNameColumn,
        Config.Identity.LastNameColumn,
        Config.Identity.GroupColumn
    )

    local function handleRow(row, lookupType)
        if not row then return false end
        local profile = profileFromRow(row)
        debugPrint(('SQL profile loaded via %s for source %s: %s | cash=%s bank=%s group=%s'):format(
            lookupType,
            tostring(source),
            profile.fullName,
            tostring(profile.cash),
            tostring(profile.bank),
            profile.group
        ))
        finish(profile)
        return true
    end

    local function runSuffixLookup()
        local suffixParameters, suffixParts, seen = {}, {}, {}
        for _, identifier in ipairs(candidates) do
            if #identifier >= 15 and not seen[identifier] then
                seen[identifier] = true
                suffixParts[#suffixParts + 1] = ('`%s` LIKE ?'):format(Config.Identity.IdentifierColumn)
                suffixParameters[#suffixParameters + 1] = '%' .. identifier
            end
        end

        if #suffixParts == 0 then
            finishFallback(('No usable SQL identifier suffix for source %s.'):format(tostring(source)))
            return
        end

        local suffixQuery = ('SELECT %s FROM `%s` WHERE %s LIMIT 1'):format(
            selectColumns,
            Config.Identity.Table,
            table.concat(suffixParts, ' OR ')
        )

        local ok, queryError = pcall(function()
            exports.oxmysql:query(suffixQuery, suffixParameters, function(rows)
                local row = firstRow(rows)
                if not handleRow(row, 'identifier suffix') then
                    finishFallback(('No users row matched source %s exact or suffix identifiers. Candidates: %s'):format(
                        tostring(source), table.concat(candidates, ', ')
                    ))
                end
            end)
        end)

        if not ok then
            finishFallback(('oxmysql suffix query failed: %s'):format(tostring(queryError)))
        end
    end

    local placeholders = {}
    for index = 1, #candidates do placeholders[index] = '?' end
    local exactQuery = ('SELECT %s FROM `%s` WHERE `%s` IN (%s) LIMIT 1'):format(
        selectColumns,
        Config.Identity.Table,
        Config.Identity.IdentifierColumn,
        table.concat(placeholders, ', ')
    )

    debugPrint(('SQL profile exact lookup for source %s using: %s'):format(tostring(source), table.concat(candidates, ', ')))

    local ok, queryError = pcall(function()
        exports.oxmysql:query(exactQuery, candidates, function(rows)
            local row = firstRow(rows)
            if not handleRow(row, 'exact identifier') then runSuffixLookup() end
        end)
    end)

    if not ok then
        debugPrint(('oxmysql exact query failed: %s; trying suffix lookup.'):format(tostring(queryError)))
        runSuffixLookup()
    end
end

local function pushProfileToClient(source, profile)
    if not GetPlayerName(source) or type(profile) ~= 'table' then return end

    TriggerClientEvent('vn-hud:client:setProfile', source, profile)

    TriggerClientEvent('vn-hud:client:setIdentity', source, profile)
end

local function sendProfile(source, forceRefresh)
    resolveProfile(source, function(profile)
        pushProfileToClient(source, profile)
    end, forceRefresh)
end

local profanityPatterns = nil

local function normalizePersianCharacters(value)
    return tostring(value or '')
        :gsub('ي', 'ی')
        :gsub('ى', 'ی')
        :gsub('ك', 'ک')
        :gsub('ؤ', 'و')
        :gsub('ۀ', 'ه')
        :gsub('ة', 'ه')
        :gsub('\226\128\140', '')
end

local function utf8Characters(value)
    local characters = {}
    local ok = pcall(function()
        for _, codepoint in utf8.codes(value) do
            characters[#characters + 1] = utf8.char(codepoint)
        end
    end)

    if not ok then
        characters = {}
        for index = 1, #value do characters[#characters + 1] = value:sub(index, index) end
    end

    return characters
end

local function truncateUtf8(value, maximumCharacters)
    local characters = utf8Characters(value)
    if #characters <= maximumCharacters then return value end

    local output = {}
    for index = 1, maximumCharacters do output[index] = characters[index] end
    return table.concat(output)
end

local function limitRepeatedCharacters(value, maximumRepeat)
    local output, lastCharacter, repeated = {}, nil, 0

    for _, character in ipairs(utf8Characters(value)) do
        if character == lastCharacter then
            repeated = repeated + 1
        else
            lastCharacter = character
            repeated = 1
        end

        if repeated <= maximumRepeat then output[#output + 1] = character end
    end

    return table.concat(output)
end

local function escapePattern(value)
    return value:gsub('([%%%^%$%(%)%.%[%]%*%+%-%?])', '%%%1')
end

local function flexibleProfanityPattern(word, english)
    word = normalizePersianCharacters(word):gsub('%s+', '')
    local pieces = {}

    for _, character in ipairs(utf8Characters(word)) do
        if english and character:match('[A-Za-z]') then
            pieces[#pieces + 1] = ('[%s%s]'):format(character:lower(), character:upper())
        else
            pieces[#pieces + 1] = escapePattern(character)
        end
    end

    local pattern = table.concat(pieces, '[%s%p_]*')
    if english then pattern = '%f[%a]' .. pattern .. '%f[%A]' end
    return pattern
end

local function getProfanityPatterns()
    if profanityPatterns then return profanityPatterns end
    profanityPatterns = {}

    local filter = Config.Chat.ProfanityFilter or {}
    for _, word in ipairs(filter.Persian or {}) do
        profanityPatterns[#profanityPatterns + 1] = flexibleProfanityPattern(word, false)
    end
    for _, word in ipairs(filter.English or {}) do
        profanityPatterns[#profanityPatterns + 1] = flexibleProfanityPattern(word, true)
    end

    return profanityPatterns
end

local function censorProfanity(message)
    local filter = Config.Chat.ProfanityFilter
    if not filter or not filter.Enabled then return message end

    message = normalizePersianCharacters(message)
    local replacement = tostring(filter.Replacement or '***')
    for _, pattern in ipairs(getProfanityPatterns()) do
        message = message:gsub(pattern, replacement)
    end
    return message
end

local function cleanChatMessage(message)
    if type(message) ~= 'string' then return nil end

    message = normalizePersianCharacters(message)
    message = message:gsub('%^%d', ''):gsub('~[%w_]+~', ''):gsub('%c', ' ')
    message = message:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    message = limitRepeatedCharacters(message, Config.Chat.AntiSpam.MaxRepeatedCharacters or 6)
    message = truncateUtf8(message, Config.Chat.MaxMessageLength)
    message = censorProfanity(message)

    return message ~= '' and message or nil
end

local function getPlayerCoords(playerSource)
    local ped = GetPlayerPed(playerSource)
    if not ped or ped <= 0 then return nil end
    local coords = GetEntityCoords(ped)
    if not coords then return nil end
    return coords
end

local function distanceBetween(first, second)
    local x, y, z = first.x - second.x, first.y - second.y, first.z - second.z
    return math.sqrt((x * x) + (y * y) + (z * z))
end

local function getNearbyPlayers(source, radius)
    local targets = { source }
    local included = { [source] = true }
    local sourceCoords = getPlayerCoords(source)
    if not sourceCoords then return targets end

    for _, player in ipairs(GetPlayers()) do
        local target = tonumber(player)
        if target and not included[target] then
            local targetCoords = getPlayerCoords(target)
            if targetCoords and distanceBetween(sourceCoords, targetCoords) <= radius then
                included[target] = true
                targets[#targets + 1] = target
            end
        end
    end

    return targets
end

local function sendToTargets(targets, eventName, payload)
    for _, target in ipairs(targets) do
        TriggerClientEvent(eventName, target, payload)
    end
end

local function sendSystemMessage(target, text, color, tag)
    TriggerClientEvent('chat:addMessage', target, {
        color = color or Config.Chat.SystemColor,
        args = { 'SERVER', text },
        tag = tag or 'SYSTEM',
        type = 'system'
    })
end

local function normalizeDuplicateKey(message)
    return normalizePersianCharacters(message)
        :lower()
        :gsub('[%s%p_]+', '')
end

local function denySpam(source, state, message)
    local now = GetGameTimer()
    if now - (state.lastWarningAt or 0) >= 2000 then
        state.lastWarningAt = now
        sendSystemMessage(source, message or 'Please slow down; chat anti-spam is active.', { 255, 184, 77 }, 'ANTI-SPAM')
    end
    return false
end

local function canSendChat(source, message)
    local now = GetGameTimer()
    local settings = Config.Chat.AntiSpam
    local state = chatSpamState[source]

    if not state then
        state = { timestamps = {}, lastAt = 0, duplicateKey = nil, duplicateAt = 0, lastWarningAt = 0 }
        chatSpamState[source] = state
    end

    if now - state.lastAt < Config.Chat.SpamCooldown then
        return denySpam(source, state, 'You are sending messages too quickly.')
    end

    local activeTimestamps = {}
    for _, timestamp in ipairs(state.timestamps) do
        if now - timestamp <= settings.WindowMs then activeTimestamps[#activeTimestamps + 1] = timestamp end
    end
    state.timestamps = activeTimestamps

    if #state.timestamps >= settings.MaxMessagesPerWindow then
        return denySpam(source, state, 'Message limit reached; wait a few seconds.')
    end

    local duplicateKey = normalizeDuplicateKey(message or '')
    if duplicateKey ~= ''
        and state.duplicateKey == duplicateKey
        and now - state.duplicateAt <= settings.DuplicateWindowMs then
        return denySpam(source, state, 'Duplicate messages are blocked.')
    end

    state.lastAt = now
    state.duplicateKey = duplicateKey
    state.duplicateAt = now
    state.timestamps[#state.timestamps + 1] = now
    return true
end

local function routeRoleplayMessage(source, mode, rawMessage, options)
    options = options or {}
    local message = cleanChatMessage(rawMessage)
    if not message then return end
    if not options.cooldownChecked and not canSendChat(source, message) then return end

    resolveProfile(source, function(profile)
        if not GetPlayerName(source) then return end


        profile = applyRuntimeIdentity(source, profile)
        local xPlayer = getXPlayer(source)
        if profile.fromDatabase == true then
            cacheProfile(getIdentifierCandidates(source, xPlayer), profile)
        end
        local displayName = chatDisplayName(source, xPlayer, profile)

        TriggerEvent('chatMessage', source, displayName, message)
        if WasEventCanceled() then return end

        local color = options.color or Config.Chat.ModeColors[mode] or Config.Chat.MessageColor
        local targets = options.global and GetPlayers() or getNearbyPlayers(source, options.distance or Config.Chat.ProximityDistance)
        local tag = options.tag or string.upper(mode)

        if not options.hideFromChat then
            sendToTargets(targets, 'chat:addMessage', {
                color = color,
                args = { displayName, message },
                tag = tag,
                type = mode,
                localMessage = not options.global
            })
        end

        if options.threeD then
            sendToTargets(targets, 'vn-hud:client:show3DText', {
                serverId = source,
                author = displayName,
                text = message,
                mode = mode,
                tag = tag,
                color = color,
                duration = Config.Chat.ThreeDDuration,
                maxDistance = Config.Chat.ThreeDDistance
            })
        end
    end, sqlIdentity[tonumber(source)] == nil)
end

local function isAnnouncementGroup(group)
    return Config.Chat.AnnouncementGroups[string.lower(tostring(group or ''))] == true
end

local function registerModeCommand(name, mode, settings)
    RegisterCommand(name, function(source, args)
        if source <= 0 then return end
        routeRoleplayMessage(source, mode, table.concat(args, ' '), settings)
    end, false)
end


AddEventHandler('esx_identity_custom:server:identityUpdated', function(playerId, xPlayer, profile)
    playerId = tonumber(playerId)
    if not playerId or playerId <= 0 or type(profile) ~= 'table' then return end
    if type(profile.fullName) ~= 'string' or cleanPart(profile.fullName) == '' then return end

    xPlayer = xPlayer or getXPlayer(playerId)
    profile.fullName = cleanPart(profile.fullName)
    profile.firstName = cleanPart(profile.firstName or profile.firstname)
    profile.lastName = cleanPart(profile.lastName or profile.lastname)
    profile.cash = math.floor(tonumber(profile.cash) or 0)
    profile.bank = math.floor(tonumber(profile.bank) or 0)
    profile.group = cleanPart(profile.group) ~= '' and cleanPart(profile.group) or 'user'
    profile.databaseGroup = profile.group
    profile.fromDatabase = true
    profile.fromIdentity = true
    rememberTrustedGroup(playerId, profile.group, true)
    rememberSqlIdentity(playerId, profile.firstName, profile.lastName)

    local candidates = getIdentifierCandidates(playerId, xPlayer)
    cacheProfile(candidates, profile)
    pushProfileToClient(playerId, profile)

    debugPrint(('Chat identity cache updated for ID %d: %s'):format(playerId, profile.fullName))
end)

-- Modern ESX emits this server-only event whenever /setgroup changes a
-- player's group. Caching it avoids depending on framework variants that keep
-- xPlayer.getGroup() stale until the player reconnects.
AddEventHandler('esx:setGroup', function(playerId, newGroup)
    playerId = tonumber(playerId)
    if not playerId or playerId <= 0 then return end
    rememberTrustedGroup(playerId, newGroup, true)
end)

RegisterNetEvent('vn-hud:server:requestProfile', function(forceRefresh)
    sendProfile(source, forceRefresh == true)
end)

RegisterNetEvent('vn-hud:server:requestIdentity', function(forceRefresh)
    sendProfile(source, forceRefresh == true)
end)

RegisterNetEvent('vn-hud:server:chatMessage', function(rawMessage)
    if not Config.Chat.Enabled then return end

    local playerSource = source
    local message = cleanChatMessage(rawMessage)
    if not message then return end

    routeRoleplayMessage(playerSource, 'ic', message, {
        distance = Config.Chat.ProximityDistance,
        tag = 'IC'
    })
end)

registerModeCommand('ic', 'ic', { distance = Config.Chat.ProximityDistance, tag = 'IC' })
registerModeCommand('ooc', 'ooc', { distance = Config.Chat.ProximityDistance, tag = 'OOC' })
registerModeCommand('looc', 'ooc', { distance = Config.Chat.ProximityDistance, tag = 'LOOC' })
registerModeCommand('b', 'ooc', { distance = Config.Chat.ProximityDistance, tag = 'OOC' })
registerModeCommand('me', 'me', { distance = Config.Chat.ThreeDDistance, tag = 'ME', threeD = true, hideFromChat = true })
registerModeCommand('action', 'me', { distance = Config.Chat.ThreeDDistance, tag = 'ME', threeD = true, hideFromChat = true })
registerModeCommand('do', 'do', { distance = Config.Chat.ThreeDDistance, tag = 'DO', threeD = true, hideFromChat = true })
registerModeCommand('scene', 'do', { distance = Config.Chat.ThreeDDistance, tag = 'DO', threeD = true, hideFromChat = true })
registerModeCommand('whisper', 'whisper', { distance = Config.Chat.WhisperDistance, tag = 'WHISPER' })
registerModeCommand('w', 'whisper', { distance = Config.Chat.WhisperDistance, tag = 'WHISPER' })
registerModeCommand('shout', 'shout', { distance = Config.Chat.ShoutDistance, tag = 'SHOUT' })
registerModeCommand('s', 'shout', { distance = Config.Chat.ShoutDistance, tag = 'SHOUT' })

RegisterCommand('try', function(source, args)
    if source <= 0 then return end
    local action = cleanChatMessage(table.concat(args, ' '))
    if not action then return end
    local success = math.random(1, 2) == 1
    local result = success and 'SUCCESS' or 'FAILED'
    local color = success and { 80, 235, 135 } or { 255, 90, 100 }
    routeRoleplayMessage(source, 'try', ('%s — %s'):format(action, result), {
        distance = Config.Chat.ThreeDDistance,
        tag = 'TRY',
        threeD = true,
        hideFromChat = true,
        color = color
    })
end, false)

RegisterCommand('roll', function(source, args)
    if source <= 0 then return end
    local maximum = math.floor(math.max(2, math.min(1000, tonumber(args[1]) or 100)))
    routeRoleplayMessage(source, 'try', ('rolled %d / %d'):format(math.random(1, maximum), maximum), {
        distance = Config.Chat.ThreeDDistance,
        tag = 'ROLL',
        threeD = true,
        hideFromChat = true
    })
end, false)

RegisterCommand('coinflip', function(source)
    if source <= 0 then return end
    local result = math.random(1, 2) == 1 and 'HEADS' or 'TAILS'
    routeRoleplayMessage(source, 'try', ('flipped a coin — %s'):format(result), {
        distance = Config.Chat.ThreeDDistance,
        tag = 'COIN',
        threeD = true,
        hideFromChat = true
    })
end, false)

RegisterCommand('id', function(source)
    if source > 0 then
        sendSystemMessage(source, ('Your server ID is %d.'):format(source), Config.Chat.SystemColor, 'ID')
    end
end, false)

local function handleAnnouncement(source, args)
    if source <= 0 then return end
    local message = cleanChatMessage(table.concat(args, ' '))
    if not message then return end

    resolveProfile(source, function(profile)
        if not isAnnouncementGroup(profile.group) then
            sendSystemMessage(source, 'You do not have permission to use /ann.', { 255, 80, 90 }, 'DENIED')
            return
        end

        routeRoleplayMessage(source, 'ann', message, {
            global = true,
            tag = 'ANNOUNCEMENT',
            color = Config.Chat.ModeColors.ann
        })
    end, false)
end

RegisterCommand('ann', handleAnnouncement, false)
RegisterCommand('announce', handleAnnouncement, false)

RegisterCommand('bot', function(source, args)
    if source <= 0 then return end
    local message = cleanChatMessage(table.concat(args, ' '))
    if not message or not canSendChat(source, message) then return end

    resolveProfile(source, function(profile)
        if not isAnnouncementGroup(profile.group) then
            sendSystemMessage(source, 'You do not have permission to use /bot.', { 255, 80, 90 }, 'DENIED')
            return
        end

        TriggerClientEvent('chat:addMessage', -1, {
            color = Config.Chat.ModeColors.bot,
            args = { 'CITY BOT', message },
            tag = 'BOT',
            type = 'bot'
        })
    end, false)
end, false)

local function sendPrivateMessage(source, target, message)
    if not canSendChat(source, message) then return end

    target = tonumber(target)
    if not target or not GetPlayerName(target) then
        sendSystemMessage(source, 'Player ID not found.', { 255, 100, 110 }, 'PM')
        return
    end

    resolveProfile(source, function(sourceProfile)
        resolveProfile(target, function(targetProfile)
            local color = Config.Chat.ModeColors.pm
            local sourceName = chatDisplayName(source, getXPlayer(source), sourceProfile)
            local targetName = chatDisplayName(target, getXPlayer(target), targetProfile)
            TriggerClientEvent('chat:addMessage', source, {
                color = color,
                args = { 'TO ' .. targetName, message },
                tag = 'PM',
                type = 'pm'
            })
            TriggerClientEvent('chat:addMessage', target, {
                color = color,
                args = { 'FROM ' .. sourceName, message },
                tag = 'PM',
                type = 'pm'
            })
            lastPrivateTarget[source] = target
            lastPrivateTarget[target] = source
        end, false)
    end, false)
end

RegisterCommand('pm', function(source, args)
    if source <= 0 then return end
    local target = table.remove(args, 1)
    local message = cleanChatMessage(table.concat(args, ' '))
    if not message then
        sendSystemMessage(source, 'Usage: /pm [id] [message]', nil, 'PM')
        return
    end
    sendPrivateMessage(source, target, message)
end, false)

RegisterCommand('reply', function(source, args)
    if source <= 0 then return end
    local message = cleanChatMessage(table.concat(args, ' '))
    local target = lastPrivateTarget[source]
    if not target or not message then
        sendSystemMessage(source, 'No private message to reply to.', nil, 'PM')
        return
    end
    sendPrivateMessage(source, target, message)
end, false)

RegisterCommand('clearchat', function(source)
    if source > 0 then TriggerClientEvent('chat:clear', source) end
end, false)

local function firstJobText(...)
    for index = 1, select('#', ...) do
        local value = select(index, ...)
        if type(value) == 'string' then
            local text = cleanPart(value)
            if text ~= '' then
                return text
            end
        end
    end
    return ''
end

local function asGradeLevel(value)
    if type(value) == 'number' then
        return value
    end
    if type(value) == 'string' and value:match('^%-?%d+$') then
        return tonumber(value)
    end
    return nil
end

local function rememberGrade(jobName, gradeLevel, gradeName, gradeLabel)
    jobName = string.lower(cleanPart(jobName))
    gradeLevel = asGradeLevel(gradeLevel)
    gradeName = cleanPart(gradeName)
    gradeLabel = cleanPart(gradeLabel)
    if jobName == '' or gradeLevel == nil then
        return
    end
    if gradeName == '' and gradeLabel == '' then
        return
    end
    gradeBook[jobName] = gradeBook[jobName] or {}
    gradeBook[jobName][gradeLevel] = {
        name = gradeName,
        label = gradeLabel
    }
end

local function lookupGradeBook(jobName, gradeLevel)
    jobName = string.lower(cleanPart(jobName))
    gradeLevel = asGradeLevel(gradeLevel)
    if jobName == '' or gradeLevel == nil then
        return nil
    end
    local grades = gradeBook[jobName]
    return type(grades) == 'table' and grades[gradeLevel] or nil
end

local function ingestEsxJobs()
    local shared = getESX()
    if not shared then
        return
    end

    local jobs = shared.Jobs
    if type(jobs) ~= 'table' and type(shared.GetJobs) == 'function' then
        local ok, result = pcall(shared.GetJobs)
        if ok then
            jobs = result
        end
    end
    if type(jobs) ~= 'table' then
        return
    end

    for jobKey, jobDef in pairs(jobs) do
        if type(jobDef) == 'table' and type(jobDef.grades) == 'table' then
            local jobName = firstJobText(jobDef.name, jobKey)
            for gradeKey, grade in pairs(jobDef.grades) do
                if type(grade) == 'table' then
                    local level = asGradeLevel(grade.grade) or asGradeLevel(grade.level) or asGradeLevel(gradeKey)
                    rememberGrade(jobName, level, grade.name, firstJobText(grade.label, grade.grade_label))
                end
            end
        end
    end
end

local function loadJobGradeBook()
    ingestEsxJobs()
    if gradeBookTried then
        return
    end
    gradeBookTried = true
    if GetResourceState('oxmysql') ~= 'started' then
        return
    end

    pcall(function()
        exports.oxmysql:query('SELECT * FROM `job_grades`', {}, function(rows)
            if type(rows) ~= 'table' then
                return
            end
            for _, row in ipairs(rows) do
                if type(row) == 'table' then
                    rememberGrade(
                        row.job_name or row.job or row.jobName,
                        row.grade or row.level or row.job_grade,
                        row.name or row.grade_name or row.gradeName,
                        row.label or row.grade_label or row.gradeLabel
                    )
                end
            end
        end)
    end)
end

local function extractJobInfo(job)
    if type(job) == 'string' then
        local name = cleanPart(job)
        if name == '' then
            return nil
        end
        return {
            name = name,
            label = name,
            gradeLevel = nil,
            gradeName = '',
            gradeLabel = ''
        }
    end

    if type(job) ~= 'table' then
        return nil
    end

    local name = firstJobText(job.name, job.Name, job.job, job.job_name, job.jobName)
    local label = firstJobText(job.label, job.Label, job.job_label, job.jobLabel)
    local gradeName = firstJobText(job.grade_name, job.gradeName, job.rank, job.rank_name, job.rankName)
    local gradeLabel = firstJobText(job.grade_label, job.gradeLabel, job.rank_label, job.rankLabel)
    local gradeLevel = asGradeLevel(job.job_grade) or asGradeLevel(job.grade_level) or asGradeLevel(job.gradeLevel)

    local nested = job.grade
    if type(nested) == 'table' then
        if gradeName == '' then
            gradeName = firstJobText(nested.name, nested.grade_name, nested.gradeName)
        end
        if gradeLabel == '' then
            gradeLabel = firstJobText(nested.label, nested.grade_label, nested.gradeLabel)
        end
        if gradeLevel == nil then
            gradeLevel = asGradeLevel(nested.level) or asGradeLevel(nested.grade) or asGradeLevel(nested.id) or asGradeLevel(nested.rank)
        end
    elseif gradeLevel == nil then
        gradeLevel = asGradeLevel(nested)
    end

    if name == '' and label == '' and gradeName == '' and gradeLabel == '' and gradeLevel == nil then
        return nil
    end

    return {
        name = name ~= '' and name or label,
        label = label ~= '' and label or name,
        gradeLevel = gradeLevel,
        gradeName = gradeName,
        gradeLabel = gradeLabel
    }
end

local function fillJobGrade(info)
    if type(info) ~= 'table' then
        return info
    end

    if info.gradeLabel == '' and info.gradeName == '' then
        local booked = lookupGradeBook(info.name, info.gradeLevel)
        if booked then
            info.gradeName = booked.name
            info.gradeLabel = booked.label
        end
    end

    return info
end

local function displayJobGrade(info)
    if type(info) ~= 'table' then
        return ''
    end

    local jobToken = string.lower(firstJobText(info.name, info.label))
    local label = cleanPart(info.gradeLabel)
    local name = cleanPart(info.gradeName)

    if label ~= '' and string.lower(label) ~= jobToken then
        return label
    end
    if name ~= '' and string.lower(name) ~= jobToken then
        return name
    end
    if label ~= '' then
        return label
    end
    return name
end

local function getLiveJob(xPlayer)
    if not xPlayer then return nil end

    if type(xPlayer.getJob) == 'function' then
        local ok, job = pcall(xPlayer.getJob)
        if ok and extractJobInfo(job) then
            return job
        end
    end

    if type(xPlayer.get) == 'function' then
        local ok, job = pcall(xPlayer.get, 'job')
        if ok and extractJobInfo(job) then
            return job
        end
    end

    if extractJobInfo(xPlayer.job) then
        return xPlayer.job
    end

    return nil
end

local function jobFromState(src)
    local ok, playerState = pcall(function()
        return Player(src).state
    end)
    if not ok or type(playerState) ~= 'table' then
        return nil
    end
    return extractJobInfo(playerState.job or playerState.Job or playerState.jobInfo)
end

local function jobFromFramework(source, xPlayer)
    xPlayer = xPlayer or getXPlayer(source)
    local info = extractJobInfo(getLiveJob(xPlayer))
    if info then
        return info
    end

    info = jobFromState(source)
    if info then
        return info
    end

    if GetResourceState('qbx_core') == 'started' then
        local ok, player = pcall(function()
            return exports.qbx_core:GetPlayer(source)
        end)
        if ok and player and type(player.PlayerData) == 'table' then
            info = extractJobInfo(player.PlayerData.job)
            if info then
                return info
            end
        end
    end

    if GetResourceState('qb-core') == 'started' then
        local ok, core = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if ok and core and core.Functions and type(core.Functions.GetPlayer) == 'function' then
            local okPlayer, player = pcall(core.Functions.GetPlayer, source)
            if okPlayer and player and type(player.PlayerData) == 'table' then
                info = extractJobInfo(player.PlayerData.job)
                if info then
                    return info
                end
            end
        end
    end

    return playerJobCache[tonumber(source)]
end

local function fetchSqlJob(source, callback)
    callback = callback or function() end
    if GetResourceState('oxmysql') ~= 'started' then
        callback(nil)
        return
    end

    local tableName = (Config.Identity and Config.Identity.Table) or 'users'
    local idColumn = (Config.Identity and Config.Identity.IdentifierColumn) or 'identifier'
    if not validSqlIdentifier(tableName) or not validSqlIdentifier(idColumn) then
        callback(nil)
        return
    end

    local candidates = getIdentifierCandidates(source, getXPlayer(source))
    if #candidates == 0 then
        callback(nil)
        return
    end

    local placeholders = {}
    for index = 1, #candidates do
        placeholders[index] = '?'
    end

    local function rowToJob(row)
        if type(row) ~= 'table' then
            return nil
        end
        local name = cleanPart(row.job or row.job_name or row.jobName)
        if name == '' then
            return nil
        end
        return {
            name = name,
            label = name,
            gradeLevel = asGradeLevel(row.job_grade or row.grade or row.jobGrade),
            gradeName = firstJobText(row.job_grade_name, row.grade_name, row.gradeName),
            gradeLabel = firstJobText(row.grade_label, row.job_grade_label, row.gradeLabel)
        }
    end

    local function takeRow(rows)
        if type(rows) ~= 'table' then
            return nil
        end
        if rows.job ~= nil or rows.job_grade ~= nil or rows.grade ~= nil then
            return rows
        end
        return rows[1]
    end

    local query = ('SELECT `job`, `job_grade` FROM `%s` WHERE `%s` IN (%s) LIMIT 1'):format(
        tableName,
        idColumn,
        table.concat(placeholders, ', ')
    )

    local ok = pcall(function()
        exports.oxmysql:query(query, candidates, function(rows)
            local info = rowToJob(takeRow(rows))
            if info then
                callback(info)
                return
            end

            local fallback = ('SELECT `job`, `grade` FROM `%s` WHERE `%s` IN (%s) LIMIT 1'):format(
                tableName,
                idColumn,
                table.concat(placeholders, ', ')
            )
            local fallbackOk = pcall(function()
                exports.oxmysql:query(fallback, candidates, function(fallbackRows)
                    callback(rowToJob(takeRow(fallbackRows)))
                end)
            end)
            if not fallbackOk then
                callback(nil)
            end
        end)
    end)

    if not ok then
        callback(nil)
    end
end

local function attachSqlGrade(info, callback)
    callback = callback or function() end
    if type(info) ~= 'table' then
        callback(nil)
        return
    end

    info = fillJobGrade(info)
    if displayJobGrade(info) ~= '' then
        callback(info)
        return
    end

    if GetResourceState('oxmysql') ~= 'started' or cleanPart(info.name) == '' or info.gradeLevel == nil then
        callback(info)
        return
    end

    local ok = pcall(function()
        exports.oxmysql:query(
            'SELECT * FROM `job_grades` WHERE (`job_name` = ? OR `job` = ?) AND (`grade` = ? OR `grade` = ?) LIMIT 1',
            { info.name, info.name, info.gradeLevel, tostring(info.gradeLevel) },
            function(rows)
                local row = nil
                if type(rows) == 'table' then
                    if rows.name ~= nil or rows.label ~= nil then
                        row = rows
                    else
                        row = rows[1]
                    end
                end
                if type(row) == 'table' then
                    info.gradeName = firstJobText(info.gradeName, row.name, row.grade_name, row.gradeName)
                    info.gradeLabel = firstJobText(info.gradeLabel, row.label, row.grade_label, row.gradeLabel)
                    rememberGrade(info.name, info.gradeLevel, info.gradeName, info.gradeLabel)
                end
                callback(fillJobGrade(info))
            end
        )
    end)

    if not ok then
        callback(info)
    end
end

local function getJobGradeLabel(job)
    local info = fillJobGrade(extractJobInfo(job))
    return displayJobGrade(info)
end

local function isStaffGroup(group)
    group = string.lower(cleanPart(group))
    local groups = Config.Chat.StaffGroups or Config.Chat.AnnouncementGroups or {}
    return groups[group] == true
end

local staffAcesReady = false
local function ensureStaffAcePermissions()
    if staffAcesReady then return end
    staffAcesReady = true

    for group, enabled in pairs(Config.Chat.StaffGroups or {}) do
        if enabled == true and type(group) == 'string' and group:match('^[%w_%-]+$') then
            ExecuteCommand(('add_ace group.%s %s allow'):format(group, STAFF_CHAT_ACE))
        end
    end
end

local function staffGroupOf(src, xPlayer, profileGroup)
    -- Trust only server-side sources: every representation exposed by the
    -- framework player, the server-only esx:setGroup event/cache, SQL profile,
    -- or an ACE permission attached to configured staff principals.
    ensureStaffAcePermissions()

    local liveGroups = getLiveGroupCandidates(xPlayer)
    for _, group in ipairs(liveGroups) do
        if isStaffGroup(group) then
            return group
        end
    end

    local cachedGroup, authoritative = readTrustedGroup(src)
    if authoritative then
        if isStaffGroup(cachedGroup) then
            return string.lower(tostring(cachedGroup))
        end
        -- A server-side setgroup demotion must override a possibly stale SQL
        -- profile, but an explicit ACE permission may still grant access.
        profileGroup = nil
    end

    local group = cleanPart(profileGroup)
    if isStaffGroup(group) then
        return string.lower(group)
    end

    if not authoritative and isStaffGroup(cachedGroup) then
        return string.lower(tostring(cachedGroup))
    end

    local okAce, allowed = pcall(IsPlayerAceAllowed, src, STAFF_CHAT_ACE)
    if okAce and allowed then
        -- Authorization is already proven by the server ACE. Preserve the
        -- configured rank when any framework/profile source exposes it.
        for _, candidate in ipairs(liveGroups) do
            if isStaffGroup(candidate) then return candidate end
        end
        if isStaffGroup(cachedGroup) then return string.lower(tostring(cachedGroup)) end
        if isStaffGroup(profileGroup) then return string.lower(cleanPart(profileGroup)) end
        return 'admin'
    end

    return nil
end

local function isUnemployed(jobName)
    jobName = string.lower(tostring(jobName or ''))
    return jobName == '' or jobName == 'unemployed' or jobName == 'unemployed2' or jobName == 'offduty'
end

local function canUseDepartment(jobName)
    jobName = string.lower(tostring(jobName or ''))
    if isUnemployed(jobName) then return false end
    local allowed = Config.Chat.DepartmentJobs
    if type(allowed) ~= 'table' or next(allowed) == nil then
        return true
    end
    return allowed[jobName] == true
end

local function collectStaffTargets()
    local targets = {}
    for _, player in ipairs(GetPlayers()) do
        local id = tonumber(player)
        if id and staffGroupOf(id, getXPlayer(id)) then
            targets[#targets + 1] = id
        end
    end
    return targets
end

local function jobNameOf(id)
    local cached = playerJobCache[tonumber(id)]
    if cached and cleanPart(cached.name) ~= '' then
        return string.lower(cached.name)
    end

    local info = jobFromFramework(id, getXPlayer(id))
    if info and cleanPart(info.name) ~= '' then
        playerJobCache[tonumber(id)] = fillJobGrade(info)
        return string.lower(info.name)
    end

    return ''
end

local function collectJobTargets(jobName)
    local targets = {}
    jobName = string.lower(tostring(jobName or ''))
    if jobName == '' then
        return targets
    end
    for _, player in ipairs(GetPlayers()) do
        local id = tonumber(player)
        if id and jobNameOf(id) == jobName then
            targets[#targets + 1] = id
        end
    end
    return targets
end

local function collectDepartmentTargets()
    local targets = {}
    for _, player in ipairs(GetPlayers()) do
        local id = tonumber(player)
        if id and canUseDepartment(jobNameOf(id)) then
            targets[#targets + 1] = id
        end
    end
    return targets
end

local function sendStyledChat(targets, tag, author, message, color, mode)
    sendToTargets(targets, 'chat:addMessage', {
        color = color,
        args = { author, message },
        tag = tag,
        type = mode,
        localMessage = false
    })
end

local function includeSelf(targets, source)
    local seen = false
    for _, id in ipairs(targets) do
        if tonumber(id) == tonumber(source) then
            seen = true
            break
        end
    end
    if not seen then
        targets[#targets + 1] = source
    end
    return targets
end

chatDisplayName = function(source, xPlayer, profile)
    local remembered = sqlIdentity[tonumber(source)]
    if remembered and cleanPart(remembered.fullName) ~= '' then
        return remembered.fullName
    end

    if type(profile) == 'table' then
        local name = joinName(profile.firstName or profile.firstname, profile.lastName or profile.lastname)
        if name ~= '' then return name end
        if profile.fromDatabase == true and cleanPart(profile.fullName) ~= '' then
            return cleanPart(profile.fullName)
        end
    end

    for _, identifier in ipairs(getIdentifierCandidates(source, xPlayer)) do
        local cached = profileCache[identifier]
        if type(cached) == 'table' and cached.fromDatabase == true then
            local name = joinName(cached.firstName or cached.firstname, cached.lastName or cached.lastname)
            if name ~= '' then return name end
        end
    end

    local firstName = cleanPart(getXPlayerField(xPlayer, { 'firstName', 'firstname', 'first_name' }))
    local lastName = cleanPart(getXPlayerField(xPlayer, { 'lastName', 'lastname', 'last_name' }))
    local name = joinName(firstName, lastName)
    if name ~= '' then return name end

    if type(profile) == 'table' and cleanPart(profile.fullName) ~= '' then
        return cleanPart(profile.fullName)
    end

    return GetPlayerName(source) or 'Player'
end

local function modeAuthor(grade, name)
    name = cleanPart(name)
    grade = cleanPart(grade)
    if grade ~= '' and name ~= '' then
        return ('%s %s :'):format(grade, name)
    end
    if name ~= '' then
        return ('%s :'):format(name)
    end
    return 'Player :'
end

local function departmentRole(jobInfo)
    if type(jobInfo) ~= 'table' then
        return ''
    end

    local jobName = firstJobText(jobInfo.label, jobInfo.name)
    local grade = displayJobGrade(jobInfo)

    if jobName == '' then return grade end
    if grade == '' or string.lower(jobName) == string.lower(grade) then return jobName end
    return ('%s %s'):format(jobName, grade)
end

local function deliverModeChat(source, mode, message, profile, jobInfo)
    local xPlayer = getXPlayer(source)
    local name = chatDisplayName(source, xPlayer, profile)
    local tag, author, color, others
    jobInfo = fillJobGrade(jobInfo or jobFromFramework(source, xPlayer))
    if jobInfo then
        playerJobCache[source] = jobInfo
    end

    if mode == 'a' then
        local profileGroup = type(profile) == 'table' and (profile.databaseGroup or profile.group) or nil
        local group = staffGroupOf(source, xPlayer, profileGroup)
        if not group then
            sendSystemMessage(source, 'You do not have permission to use /a.', { 255, 80, 90 }, 'DENIED')
            return
        end

        local labels = (Config.Chat and Config.Chat.StaffRankLabels) or {}
        local rank = labels[group] or string.upper(group)
        tag = 'ADMIN'
        author = ('%s %s'):format(rank, name)
        color = Config.Chat.ModeColors.admin or { 255, 196, 72 }
        others = collectStaffTargets()
    elseif mode == 'f' then
        local jobName = jobInfo and jobInfo.name or ''
        if isUnemployed(jobName) then
            sendSystemMessage(source, 'You need a job to use /f.', { 255, 80, 90 }, 'DENIED')
            return
        end

        local grade = displayJobGrade(jobInfo)
        tag = 'F'
        author = modeAuthor(grade, name)
        color = Config.Chat.ModeColors.job or { 120, 210, 255 }
        others = collectJobTargets(jobName)
    elseif mode == 'dep' then
        local jobName = jobInfo and jobInfo.name or ''
        if isUnemployed(jobName) then
            sendSystemMessage(source, 'You need a job to use /dep.', { 255, 80, 90 }, 'DENIED')
            return
        end
        if not canUseDepartment(jobName) then
            sendSystemMessage(source, 'Your job cannot use /dep.', { 255, 80, 90 }, 'DENIED')
            return
        end

        tag = 'DEP'
        author = modeAuthor(departmentRole(jobInfo), name)
        color = Config.Chat.ModeColors.dep or { 255, 140, 90 }
        others = collectDepartmentTargets()
    else
        return
    end

    sendToTargets(includeSelf(others, source), 'chat:addMessage', {
        color = color,
        args = { author, message },
        tag = tag,
        type = mode,
        localMessage = false
    })
end

local lastModeChat = {}

local function handleModeChat(source, mode, rawMessage)
    source = tonumber(source)
    if not source or source <= 0 then return end

    local message = cleanChatMessage(tostring(rawMessage or ''))
    if not message then return end

    local now = GetGameTimer()
    local prev = lastModeChat[source]
    if prev and prev.mode == mode and prev.message == message and (now - prev.at) < 800 then
        return
    end
    lastModeChat[source] = { mode = mode, message = message, at = now }

    loadJobGradeBook()

    resolveProfile(source, function(profile)
        local jobInfo = fillJobGrade(jobFromFramework(source, getXPlayer(source)))
        local finished = false
        local function finish(info)
            if finished then
                return
            end
            finished = true
            deliverModeChat(source, mode, message, profile, fillJobGrade(info or jobInfo))
        end

        local function mergeJob(extra)
            if type(extra) ~= 'table' then
                return jobInfo
            end
            if type(jobInfo) ~= 'table' then
                jobInfo = extra
                return jobInfo
            end
            if cleanPart(jobInfo.name) == '' then
                jobInfo.name = extra.name
                jobInfo.label = firstJobText(jobInfo.label, extra.label, extra.name)
            end
            if jobInfo.gradeLevel == nil then
                jobInfo.gradeLevel = extra.gradeLevel
            end
            if jobInfo.gradeName == '' then
                jobInfo.gradeName = extra.gradeName
            end
            if jobInfo.gradeLabel == '' then
                jobInfo.gradeLabel = extra.gradeLabel
            end
            return jobInfo
        end

        SetTimeout(900, function()
            finish(jobInfo)
        end)

        if displayJobGrade(jobInfo) ~= '' then
            finish(jobInfo)
        elseif jobInfo and cleanPart(jobInfo.name) ~= '' and jobInfo.gradeLevel ~= nil then
            attachSqlGrade(jobInfo, finish)
        else
            fetchSqlJob(source, function(sqlJob)
                attachSqlGrade(fillJobGrade(mergeJob(sqlJob)), finish)
            end)
        end
    end, true)
end

RegisterCommand('a', function(source, args)
    handleModeChat(source, 'a', table.concat(args or {}, ' '))
end, false)

RegisterCommand('f', function(source, args)
    handleModeChat(source, 'f', table.concat(args or {}, ' '))
end, false)

RegisterCommand('dep', function(source, args)
    handleModeChat(source, 'dep', table.concat(args or {}, ' '))
end, false)

RegisterNetEvent('vn-hud:server:modeChat')
AddEventHandler('vn-hud:server:modeChat', function(mode, rawMessage)
    mode = tostring(mode or '')
    if mode ~= 'a' and mode ~= 'f' and mode ~= 'dep' then return end
    handleModeChat(source, mode, rawMessage)
end)

CreateThread(function()
    local bot = Config.Chat and Config.Chat.AutoBot
    if not bot or bot.Enabled == false then return end

    local interval = math.max(60000, math.floor((tonumber(bot.IntervalMinutes) or 15) * 60 * 1000))
    local messages = {}
    if type(bot.DiscordInvite) == 'string' and bot.DiscordInvite ~= '' then
        messages[#messages + 1] = ('Discord: %s'):format(bot.DiscordInvite)
    end
    for _, text in ipairs(bot.Messages or {}) do
        if type(text) == 'string' and text ~= '' then
            messages[#messages + 1] = text
        end
    end
    if #messages == 0 then return end

    local index = 1
    Wait(45000)
    while true do
        local text = messages[index]
        index = index + 1
        if index > #messages then index = 1 end

        if type(text) == 'string' and text ~= '' then
            TriggerClientEvent('chat:addMessage', -1, {
                color = Config.Chat.ModeColors.bot or Config.Chat.SystemColor,
                args = { bot.Tag or 'CITY BOT', text },
                tag = 'BOT',
                type = 'bot'
            })
        end
        Wait(interval)
    end
end)

RegisterNetEvent('chat:init', function()
    sendProfile(source, false)
end)

exports('AddChatMessage', function(target, message)
    if message == nil then message, target = target, -1 end
    TriggerClientEvent('chat:addMessage', tonumber(target) or -1, message)
end)


AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    playerId = tonumber(playerId) or tonumber(source)
    if not playerId or playerId <= 0 then return end

    xPlayer = xPlayer or getXPlayer(playerId)
    rememberTrustedGroup(playerId, getLiveGroup(xPlayer), true)

    local jobInfo = extractJobInfo(type(xPlayer) == 'table' and (xPlayer.job or (type(xPlayer.getJob) == 'function' and xPlayer.getJob())) or nil)
    if jobInfo then
        playerJobCache[playerId] = fillJobGrade(jobInfo)
    end

    CreateThread(function()
        Wait(250)

        sendProfile(playerId, true)
        Wait(750)
        sendProfile(playerId, true)
    end)
end)

AddEventHandler('esx:setJob', function(playerId, job)
    playerId = tonumber(playerId) or tonumber(source)
    if not playerId or playerId <= 0 then
        return
    end
    local jobInfo = extractJobInfo(job)
    if jobInfo then
        playerJobCache[playerId] = fillJobGrade(jobInfo)
    end
end)

AddEventHandler('playerJoining', function()
    local playerSource = source
    sendProfile(playerSource, true)
end)

AddEventHandler('playerDropped', function()
    local playerSource = source
    chatSpamState[playerSource] = nil
    lastPrivateTarget[playerSource] = nil
    lastModeChat[playerSource] = nil
    sqlIdentity[playerSource] = nil
    trustedGroupCache[playerSource] = nil
    playerJobCache[playerSource] = nil
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE_NAME then
        if resourceName == 'es_extended' then
            ESX = nil
            getESX()
        elseif resourceName == 'chat' and Config.Chat.Enabled and Config.Chat.StopDefaultChatResource then
            CreateThread(function()
                Wait(250)
                if GetResourceState('chat') == 'started' then StopResource('chat') end
            end)
        end
        return
    end

    CreateThread(function()
        Wait(750)
        getESX()
        math.randomseed(os.time())

        if Config.Chat.Enabled and Config.Chat.StopDefaultChatResource and GetResourceState('chat') == 'started' then
            debugPrint('Stopping default chat to prevent duplicate UI/input.')
            StopResource('chat')
        end
    end)
end)


local NEEDS_MAX = 1000000.0
local KVP_PREFIX = 'vn-hud:need:'
local INIT_PREFIX = 'vn-hud:needinit:'


local needsCache = {}


local needsIdentifier = {}


local needsCandidates = {}


local needsSynced = {}


local needsSqlTable = nil


local fileStore = { version = 1, players = {} }
local fileStoreLoaded = false

local function needsEnabled()
    return Config.Needs
        and Config.Needs.Enabled
        and Config.Needs.SaveEnabled
        and not Config.Needs.UseExternalStatus
end

local function needsDebug(_)
end

local function needsLog(_)
end

local function clampNeedValue(value, fallback)
    value = tonumber(value)
    if not value then return fallback end
    if value < 0 then return 0.0 end
    if value > 100 then return 100.0 end
    return value + 0.0
end

local function decodeNeeds(raw)
    if not raw or raw == '' then return nil end

    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then return nil end

    local result = {}

    for _, entry in ipairs(decoded) do
        if type(entry) == 'table' and entry.name then
            local percent = tonumber(entry.percent)

            if not percent and tonumber(entry.val) then
                percent = (tonumber(entry.val) / NEEDS_MAX) * 100.0
            end

            if percent then
                result[entry.name] = clampNeedValue(percent, nil)
            end
        end
    end

    if result.hunger or result.thirst then
        return result
    end

    if tonumber(decoded.hunger) or tonumber(decoded.thirst) then
        return {
            hunger = clampNeedValue(decoded.hunger, nil),
            thirst = clampNeedValue(decoded.thirst, nil)
        }
    end

    return nil
end

local function encodeNeeds(values)
    local hunger = clampNeedValue(values.hunger, 100.0)
    local thirst = clampNeedValue(values.thirst, 100.0)

    return json.encode({
        { name = 'hunger', val = math.floor((hunger / 100.0) * NEEDS_MAX), percent = hunger },
        { name = 'thirst', val = math.floor((thirst / 100.0) * NEEDS_MAX), percent = thirst }
    })
end

local function needsColumn()
    local column = (Config.Needs and Config.Needs.SaveColumn) or 'status'
    if not validSqlIdentifier(column) then return nil end
    return column
end

local function needsUsersTable()
    local tableName = (Config.Identity and Config.Identity.Table) or 'users'
    if not validSqlIdentifier(tableName) then return nil end
    return tableName
end

local function needsIdColumn()
    local column = (Config.Identity and Config.Identity.IdentifierColumn) or 'identifier'
    if not validSqlIdentifier(column) then return nil end
    return column
end

local function oxmysqlReady()
    return GetResourceState('oxmysql') == 'started'
end

local function mysqlAwait(method, query, params)
    params = params or {}

    if not oxmysqlReady() then
        return nil
    end

    if MySQL and type(MySQL) == 'table' then
        local api = MySQL[method]
        if type(api) == 'table' and type(api.await) == 'function' then
            local ok, result = pcall(api.await, query, params)
            if ok then return result end
        end
    end

    local function awaitPromise(value)
        if type(value) == 'table' and (value.state ~= nil or value.next ~= nil) then
            local waitOk, waitResult = pcall(Citizen.Await, value)
            if waitOk then return waitResult end
            return nil
        end
        return value
    end

    local asyncName = method .. '_async'
    local syncName = method .. 'Sync'
    local attempts = { asyncName, syncName, method }

    for _, name in ipairs(attempts) do
        local ok, result = pcall(function()
            return exports.oxmysql[name](exports.oxmysql, query, params)
        end)
        if ok and result ~= nil then
            return awaitPromise(result)
        end
    end

    local p = promise.new()
    local invoked = pcall(function()
        exports.oxmysql[method](exports.oxmysql, query, params, function(result)
            p:resolve(result)
        end)
    end)

    if not invoked then
        return nil
    end

    SetTimeout(4000, function()
        p:resolve(nil)
    end)

    local ok, result = pcall(function()
        return Citizen.Await(p)
    end)
    if ok then return result end
    return nil
end

local function mysqlCallback(method, query, params, cb)
    cb = cb or function() end
    if not oxmysqlReady() then
        cb(nil)
        return
    end

    local ok = pcall(function()
        exports.oxmysql[method](exports.oxmysql, query, params, cb)
    end)

    if not ok then
        CreateThread(function()
            local result = mysqlAwait(method, query, params)
            cb(result)
        end)
    end
end

local function qualifiedNeedsTable(withDatabase)
    local tableName = (Config.Needs and Config.Needs.SaveTable) or 'vn_hud_needs'
    if not validSqlIdentifier(tableName) then return nil end

    local database = Config.Needs and Config.Needs.Database
    if withDatabase and type(database) == 'string' and validSqlIdentifier(database) then
        return ('`%s`.`%s`'):format(database, tableName)
    end

    return ('`%s`'):format(tableName)
end

local function createTableSql(tableName)
    return ([[
        CREATE TABLE IF NOT EXISTS %s (
            `identifier` VARCHAR(80) NOT NULL,
            `hunger` DOUBLE NOT NULL DEFAULT 100,
            `thirst` DOUBLE NOT NULL DEFAULT 100,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]):format(tableName)
end

local function probeTable(tableName)
    if not tableName then return false end
    local rows = mysqlAwait('query', ('SELECT `identifier` FROM %s LIMIT 1'):format(tableName), {})
    return type(rows) == 'table'
end

local function ensureNeedsTable()
    if not oxmysqlReady() then
        needsLog('oxmysql unavailable')
        return false
    end

    local candidates = {
        qualifiedNeedsTable(true),
        qualifiedNeedsTable(false)
    }

    for _, tableName in ipairs(candidates) do
        if tableName then
            mysqlAwait('execute', createTableSql(tableName), {})
            mysqlAwait('query', createTableSql(tableName), {})

            if probeTable(tableName) then
                needsSqlTable = tableName
                needsLog(('needs table ready: %s'):format(tableName))
                return true
            end
        end
    end

    needsLog('needs table missing')
    return false
end

local function backupPaths()
    local configured = (Config.Needs and Config.Needs.FileBackupPath) or 'data/needs.json'
    return { configured, 'needs_store.json' }
end

local function loadFileStore()
    if fileStoreLoaded then return fileStore end
    fileStoreLoaded = true
    fileStore = { version = 1, players = {} }

    if Config.Needs and Config.Needs.FileBackup == false then
        return fileStore
    end

    for _, path in ipairs(backupPaths()) do
        local raw = LoadResourceFile(RESOURCE_NAME, path)
        if type(raw) == 'string' and raw ~= '' then
            local ok, decoded = pcall(json.decode, raw)
            if ok and type(decoded) == 'table' then
                local players = decoded.players or decoded
                if type(players) == 'table' then
                    fileStore.players = players
                    needsDebug(('file backup loaded from %s (%d entries)'):format(path, 0))
                    return fileStore
                end
            end
        end
    end

    return fileStore
end

local function writeFileStore()
    if Config.Needs and Config.Needs.FileBackup == false then
        return false
    end

    loadFileStore()
    local payload = json.encode({
        version = 1,
        savedAt = os.time(),
        players = fileStore.players or {}
    })

    local wrote = false
    for _, path in ipairs(backupPaths()) do
        local ok = SaveResourceFile(RESOURCE_NAME, path, payload, #payload)
        if ok ~= false then
            wrote = true
        end
    end

    return wrote
end

local function fileLookup(candidates)
    loadFileStore()
    local players = fileStore.players or {}
    for _, identifier in ipairs(candidates or {}) do
        local row = players[identifier]
        if type(row) == 'table' and (row.hunger or row.thirst) then
            return {
                hunger = clampNeedValue(row.hunger, nil),
                thirst = clampNeedValue(row.thirst, nil),
                initialized = row.initialized == true or tonumber(row.initialized) == 1
            }, identifier, 'file'
        end
    end
    return nil, nil, nil
end

local function fileUpsert(identifier, candidates, values)
    if Config.Needs and Config.Needs.FileBackup == false then
        return false
    end

    loadFileStore()
    fileStore.players = fileStore.players or {}

    local payload = {
        hunger = clampNeedValue(values.hunger, 100.0),
        thirst = clampNeedValue(values.thirst, 100.0),
        initialized = true,
        updated = os.time()
    }

    local keys = {}
    local seen = {}
    local function addKey(key)
        if type(key) == 'string' and key ~= '' and not seen[key] then
            seen[key] = true
            keys[#keys + 1] = key
        end
    end

    addKey(identifier)
    for _, key in ipairs(candidates or {}) do addKey(key) end

    if #keys == 0 then return false end

    for _, key in ipairs(keys) do
        fileStore.players[key] = payload
    end

    return writeFileStore()
end

local function kvpLookup(candidates)
    for _, identifier in ipairs(candidates or {}) do
        local raw = GetResourceKvpString(KVP_PREFIX .. identifier)
        local decoded = decodeNeeds(raw)
        if decoded then
            local okRaw, rawTable = pcall(json.decode, raw)
            if okRaw and type(rawTable) == 'table' then
                decoded.initialized = rawTable.initialized == true or tonumber(rawTable.initialized) == 1
            end
            return decoded, identifier, 'kvp'
        end
    end
    return nil, nil, nil
end

local function kvpUpsert(identifier, candidates, values)
    local payload = json.encode({
        hunger = clampNeedValue(values.hunger, 100.0),
        thirst = clampNeedValue(values.thirst, 100.0),
        initialized = true,
        updated = os.time()
    })

    local keys, seen = {}, {}
    local function addKey(key)
        if type(key) == 'string' and key ~= '' and not seen[key] then
            seen[key] = true
            keys[#keys + 1] = key
        end
    end

    addKey(identifier)
    for _, key in ipairs(candidates or {}) do addKey(key) end

    for _, key in ipairs(keys) do
        SetResourceKvp(KVP_PREFIX .. key, payload)
    end

    return #keys > 0
end

local function collectNeedKeys(identifier, candidates)
    local keys, seen = {}, {}
    local function addKey(key)
        if type(key) == 'string' and key ~= '' and not seen[key] then
            seen[key] = true
            keys[#keys + 1] = key
        end
    end

    addKey(identifier)
    for _, key in ipairs(candidates or {}) do addKey(key) end
    return keys
end

local function needsMarkedInitialized(identifier, candidates, values)
    if values and (values.initialized == true or tonumber(values.initialized) == 1) then
        return true
    end

    loadFileStore()

    for _, key in ipairs(collectNeedKeys(identifier, candidates)) do
        if GetResourceKvpString(INIT_PREFIX .. key) == '1' then
            return true
        end

        local row = fileStore.players and fileStore.players[key]
        if type(row) == 'table' and (row.initialized == true or tonumber(row.initialized) == 1) then
            return true
        end
    end

    return false
end

local function markNeedsInitialized(identifier, candidates)
    for _, key in ipairs(collectNeedKeys(identifier, candidates)) do
        SetResourceKvp(INIT_PREFIX .. key, '1')
        if fileStore.players and type(fileStore.players[key]) == 'table' then
            fileStore.players[key].initialized = true
        end
    end
end

local function rememberIdentifiers(source)
    if not source then return {} end

    local xPlayer = nil
    local sharedObject = getESX()
    if sharedObject and type(sharedObject.GetPlayerFromId) == 'function' then
        local ok, player = pcall(sharedObject.GetPlayerFromId, source)
        if ok then xPlayer = player end
    end

    local candidates = getIdentifierCandidates(source, xPlayer)
    if #candidates > 0 then
        needsCandidates[source] = candidates
        if not needsIdentifier[source] then
            needsIdentifier[source] = candidates[1]
        end
    end

    return needsCandidates[source] or {}
end

local function fetchFromDedicated(candidates, callback)
    if not needsSqlTable or not oxmysqlReady() or not candidates or #candidates == 0 then
        callback(nil, nil)
        return
    end

    local placeholders = {}
    for i = 1, #candidates do placeholders[i] = '?' end

    local query = ('SELECT `identifier`, `hunger`, `thirst` FROM %s WHERE `identifier` IN (%s) LIMIT 1'):format(
        needsSqlTable, table.concat(placeholders, ', ')
    )

    mysqlCallback('query', query, candidates, function(rows)
        local row = type(rows) == 'table' and rows[1] or nil
        if row and (row.hunger ~= nil or row.thirst ~= nil) then
            callback({
                hunger = clampNeedValue(row.hunger, nil),
                thirst = clampNeedValue(row.thirst, nil)
            }, row.identifier)
            return
        end

        local suffixParts, suffixParams, seen = {}, {}, {}
        for _, identifier in ipairs(candidates) do
            if #identifier >= 15 and not seen[identifier] then
                seen[identifier] = true
                suffixParts[#suffixParts + 1] = '`identifier` LIKE ?'
                suffixParams[#suffixParams + 1] = '%' .. identifier
            end
        end

        if #suffixParts == 0 then
            callback(nil, nil)
            return
        end

        local suffixQuery = ('SELECT `identifier`, `hunger`, `thirst` FROM %s WHERE %s LIMIT 1'):format(
            needsSqlTable, table.concat(suffixParts, ' OR ')
        )

        mysqlCallback('query', suffixQuery, suffixParams, function(suffixRows)
            local suffixRow = type(suffixRows) == 'table' and suffixRows[1] or nil
            if suffixRow and (suffixRow.hunger ~= nil or suffixRow.thirst ~= nil) then
                callback({
                    hunger = clampNeedValue(suffixRow.hunger, nil),
                    thirst = clampNeedValue(suffixRow.thirst, nil)
                }, suffixRow.identifier)
            else
                callback(nil, nil)
            end
        end)
    end)
end

local function fetchFromUsersStatus(candidates, callback)
    if not oxmysqlReady() or not candidates or #candidates == 0 then
        callback(nil, nil)
        return
    end

    local tbl = needsUsersTable()
    local idCol = needsIdColumn()
    local col = needsColumn()
    if not (tbl and idCol and col) then
        callback(nil, nil)
        return
    end

    local placeholders = {}
    for i = 1, #candidates do placeholders[i] = '?' end

    local query = ('SELECT `%s`, `%s` FROM `%s` WHERE `%s` IN (%s) LIMIT 1'):format(
        idCol, col, tbl, idCol, table.concat(placeholders, ', ')
    )

    mysqlCallback('query', query, candidates, function(rows)
        local row = type(rows) == 'table' and rows[1] or nil
        if not row then
            callback(nil, nil)
            return
        end

        local decoded = decodeNeeds(row[col])
        callback(decoded, row[idCol])
    end)
end

local function fetchNeeds(source, callback)
    local candidates = rememberIdentifiers(source)

    if #candidates == 0 then
        needsDebug(('no identifier candidates for source %s'):format(tostring(source)))
        callback(nil, nil, nil)
        return
    end

    fetchFromDedicated(candidates, function(sqlValues, sqlIdentifier)
        if sqlValues then
            callback(sqlValues, sqlIdentifier or candidates[1], 'sql')
            return
        end

        local fileValues, fileIdentifier = fileLookup(candidates)
        if fileValues then
            callback(fileValues, fileIdentifier or candidates[1], 'file')
            return
        end

        local kvpValues, kvpIdentifier = kvpLookup(candidates)
        if kvpValues then
            callback(kvpValues, kvpIdentifier or candidates[1], 'kvp')
            return
        end

        fetchFromUsersStatus(candidates, function(legacyValues, legacyIdentifier)
            local h = legacyValues and tonumber(legacyValues.hunger)
            local t = legacyValues and tonumber(legacyValues.thirst)
            if legacyValues and not ((not h or h <= 0.5) and (not t or t <= 0.5)) then
                callback(legacyValues, legacyIdentifier or candidates[1], 'users.status')
                return
            end

            callback(nil, candidates[1], nil)
        end)
    end)
end

local function sqlUpsert(identifier, hunger, thirst)
    if not needsSqlTable and oxmysqlReady() then
        ensureNeedsTable()
    end

    if not needsSqlTable or not identifier or not oxmysqlReady() then
        return false
    end

    local query = ('INSERT INTO %s (`identifier`, `hunger`, `thirst`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `hunger` = ?, `thirst` = ?'):format(needsSqlTable)
    local params = { identifier, hunger, thirst, hunger, thirst }
    local result = mysqlAwait('execute', query, params)
    if result == nil then
        result = mysqlAwait('update', query, params)
    end
    if result == nil then
        result = mysqlAwait('query', query, params)
    end
    return result ~= nil
end

local function persistNeedsSnapshot(identifier, candidates, values, reason)
    if type(values) ~= 'table' then return false end

    local hunger = clampNeedValue(values.hunger, 100.0)
    local thirst = clampNeedValue(values.thirst, 100.0)
    local payload = { hunger = hunger, thirst = thirst, initialized = true }

    if (not identifier or identifier == '') and type(candidates) == 'table' then
        identifier = candidates[1]
    end

    local sqlOk = false
    if identifier then
        sqlOk = sqlUpsert(identifier, hunger, thirst)
    end

    local fileOk = fileUpsert(identifier, candidates, payload)
    local kvpOk = kvpUpsert(identifier, candidates, payload)
    markNeedsInitialized(identifier, candidates)

    if Config.Needs and Config.Needs.AlsoWriteUsersStatus and identifier then
        local tbl = needsUsersTable()
        local idCol = needsIdColumn()
        local col = needsColumn()
        if tbl and idCol and col and oxmysqlReady() then
            pcall(function()
                exports.oxmysql:update(
                    ('UPDATE `%s` SET `%s` = ? WHERE `%s` = ?'):format(tbl, col, idCol),
                    { encodeNeeds(payload), identifier }
                )
            end)
        end
    end

    needsLog(('needs save (%s) %s | hunger=%.1f thirst=%.1f | sql=%s file=%s kvp=%s'):format(
        reason or 'save',
        tostring(identifier or '?'),
        hunger,
        thirst,
        sqlOk and 'ok' or 'no',
        fileOk and 'ok' or 'no',
        kvpOk and 'ok' or 'no'
    ))

    return sqlOk or fileOk or kvpOk
end

local function persistNeeds(source, values, reason)
    if type(values) ~= 'table' then return false end

    local candidates = rememberIdentifiers(source)
    local identifier = needsIdentifier[source] or candidates[1]
    return persistNeedsSnapshot(identifier, candidates, values, reason or 'save')
end


local needsLoadAttempts = {}

local function loadNeedsFor(source)
    local _source = source
    if not _source then return end

    needsLoadAttempts[_source] = (needsLoadAttempts[_source] or 0) + 1
    local candidates = rememberIdentifiers(_source)

    if #candidates == 0 then
        if needsLoadAttempts[_source] < 8 then
            SetTimeout(1500, function()
                if GetPlayerName(_source) then
                    loadNeedsFor(_source)
                end
            end)
        else
            local startValue = (Config.Needs and Config.Needs.StartValue) or 100.0
            local payload = { hunger = startValue, thirst = startValue }
            needsCache[_source] = payload
            TriggerClientEvent('vn-hud:client:loadNeeds', _source, payload)
            needsLog(('no identifier for %s'):format(tostring(_source)))
        end
        return
    end

    fetchNeeds(_source, function(values, identifier, sourceName)
        if identifier then
            needsIdentifier[_source] = identifier
        end

        local startValue = (Config.Needs and Config.Needs.StartValue) or 100.0
        local hunger = values and tonumber(values.hunger)
        local thirst = values and tonumber(values.thirst)
        local bothEmpty = (not hunger or hunger <= 0.5) and (not thirst or thirst <= 0.5)
        local initialized = needsMarkedInitialized(identifier, candidates, values)
        local treatEmpty = Config.Needs == nil or Config.Needs.TreatBothEmptyAsFirstJoin ~= false


        local firstJoin = (not values) or (treatEmpty and bothEmpty and not initialized)

        local payload
        if firstJoin then
            payload = { hunger = startValue, thirst = startValue }
        else
            payload = {
                hunger = clampNeedValue(hunger, startValue),
                thirst = clampNeedValue(thirst, startValue)
            }
        end

        needsCache[_source] = payload
        needsSynced[_source] = false

        TriggerClientEvent('vn-hud:client:loadNeeds', _source, payload)

        if firstJoin then
            CreateThread(function()
                persistNeedsSnapshot(identifier or candidates[1], candidates, payload, 'first-join')
            end)
        end

        needsLog(('needs load %s (%s) | hunger=%.1f thirst=%.1f | src=%s'):format(
            tostring(_source),
            tostring(identifier or candidates[1] or '?'),
            payload.hunger,
            payload.thirst,
            sourceName or 'default'
        ))


        if sourceName and sourceName ~= 'sql' and identifier then
            CreateThread(function()
                persistNeedsSnapshot(identifier, candidates, payload, 'migrate:' .. sourceName)
            end)
        end
    end)
end

RegisterNetEvent('vn-hud:server:requestNeeds', function()
    local _source = source
    if not needsEnabled() then
        TriggerClientEvent('vn-hud:client:loadNeeds', _source, {})
        return
    end
    loadNeedsFor(_source)
end)

RegisterNetEvent('vn-hud:server:syncNeeds', function(values)
    local _source = source
    if not needsEnabled() then return end
    if type(values) ~= 'table' then return end

    rememberIdentifiers(_source)
    needsCache[_source] = {
        hunger = clampNeedValue(values.hunger, 100.0),
        thirst = clampNeedValue(values.thirst, 100.0)
    }
    needsSynced[_source] = true
end)

RegisterNetEvent('vn-hud:server:saveNeeds', function(values)
    local _source = source
    if not needsEnabled() then return end
    if type(values) ~= 'table' then return end

    local payload = {
        hunger = clampNeedValue(values.hunger, 100.0),
        thirst = clampNeedValue(values.thirst, 100.0)
    }

    rememberIdentifiers(_source)
    needsCache[_source] = payload
    needsSynced[_source] = true

    CreateThread(function()
        persistNeeds(_source, payload, 'client')
    end)
end)

AddEventHandler('esx:playerLoaded', function(playerId)
    if not needsEnabled() then return end
    playerId = tonumber(playerId) or tonumber(source)
    if not playerId or playerId <= 0 then return end

    SetTimeout(400, function()
        if GetPlayerName(playerId) then
            loadNeedsFor(playerId)
        end
    end)
end)

local needsSavedOnDrop = {}

local function handleNeedsDrop(source, reason)
    if not needsEnabled() then return end
    if not source then return end
    if needsSavedOnDrop[source] then return end

    needsSavedOnDrop[source] = true


    local candidates = rememberIdentifiers(source)
    local identifier = needsIdentifier[source] or (candidates and candidates[1])
    local values = needsCache[source]
    local synced = needsSynced[source] == true

    if values and synced then
        persistNeedsSnapshot(identifier, candidates, values, reason or 'drop')
    else
        needsDebug(('skipped save on drop for %s (client never synced)'):format(tostring(source)))
    end

    needsCache[source] = nil
    needsIdentifier[source] = nil
    needsCandidates[source] = nil
    needsSynced[source] = nil
    needsLoadAttempts[source] = nil

    SetTimeout(10000, function()
        needsSavedOnDrop[source] = nil
    end)
end

AddEventHandler('esx:playerDropped', function(playerId)
    handleNeedsDrop(tonumber(playerId) or playerId, 'esx-drop')
end)

AddEventHandler('playerDropped', function()
    handleNeedsDrop(source, 'drop')
end)

AddEventHandler('esx:playerLogout', function(playerId)
    handleNeedsDrop(playerId or source, 'logout')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if not needsEnabled() then return end

    for playerId, values in pairs(needsCache) do
        if needsSynced[playerId] then
            local candidates = needsCandidates[playerId] or {}
            local identifier = needsIdentifier[playerId] or candidates[1]
            persistNeedsSnapshot(identifier, candidates, values, 'resource-stop')
        end
    end
end)

CreateThread(function()
    if not needsEnabled() then return end

    local waited = 0
    while GetResourceState('oxmysql') ~= 'started' and waited < 15000 do
        Wait(250)
        waited = waited + 250
    end

    ensureNeedsTable()
    loadFileStore()
    loadJobGradeBook()
    needsLog('needs store ready')
end)


CreateThread(function()
    if not Config.Needs or not Config.Needs.Enabled then return end

    local commandName = Config.Needs.AdminCommand or 'setneed'

    RegisterCommand(commandName, function(source, args)
        local _source = source

        local function reply(message)
            if _source == 0 then
                return
            else
                TriggerClientEvent('chat:addMessage', _source, {
                    color = { 53, 223, 196 },
                    args  = { 'vn-hud', message }
                })
            end
        end


        if _source > 0 then
            local sharedObject = getESX()
            local xPlayer      = nil

            if sharedObject and type(sharedObject.GetPlayerFromId) == 'function' then
                local ok, player = pcall(sharedObject.GetPlayerFromId, _source)
                if ok then xPlayer = player end
            end

            local group = nil
            if xPlayer then
                if type(xPlayer.getGroup) == 'function' then
                    local ok, value = pcall(xPlayer.getGroup)
                    if ok then group = value end
                end
                group = group or xPlayer.group
            end

            if not (Config.Needs.AdminGroups or {})[group] then
                reply('No permission.')
                return
            end
        end

        local needName = args[1]
        local percent  = tonumber(args[2])
        local target   = tonumber(args[3]) or _source

        if (needName ~= 'hunger' and needName ~= 'thirst') or not percent or target == 0 then
            reply(('Usage: /%s <hunger|thirst> <0-100> [playerId]'):format(commandName))
            return
        end

        percent = clampNeedValue(percent, 100.0)

        local current = needsCache[target] or {
            hunger = (Config.Needs and Config.Needs.StartValue) or 100.0,
            thirst = (Config.Needs and Config.Needs.StartValue) or 100.0
        }
        current[needName] = percent
        needsCache[target] = current
        needsSynced[target] = true
        rememberIdentifiers(target)

        TriggerClientEvent('vn-hud:client:setNeed', target, needName, percent)

        CreateThread(function()
            persistNeeds(target, current, 'admin')
        end)

        reply(('%s set to %.0f for %s.'):format(needName, percent, target))
    end, false)
end)


CreateThread(function()
    if not Config.Needs or not Config.Needs.Enabled then return end
    if Config.Needs.UseExternalStatus then return end

    local items = Config.Needs.UsableItems
    if not items or not items.Enabled then return end


    local sharedObject = nil
    local waited       = 0

    while not sharedObject and waited < 30000 do
        sharedObject = getESX()
        if sharedObject then break end
        Wait(500)
        waited = waited + 500
    end

    if not sharedObject or type(sharedObject.RegisterUsableItem) ~= 'function' then
        needsDebug('ESX.RegisterUsableItem not available; usable items are disabled.')
        return
    end

    local registered = 0


    local function registerConsumable(itemName, amount, kind)
        if type(itemName) ~= 'string' or not tonumber(amount) then return end

        sharedObject.RegisterUsableItem(itemName, function(source)
            local _source = source

            local xPlayer = nil
            local ok, player = pcall(sharedObject.GetPlayerFromId, _source)
            if ok then xPlayer = player end

            if not xPlayer then return end


            local removed = pcall(function()
                xPlayer.removeInventoryItem(itemName, 1)
            end)

            if not removed then
                needsDebug(('failed to remove item %s from %s'):format(itemName, tostring(_source)))
                return
            end

            TriggerClientEvent('vn-hud:client:consume', _source, kind, tonumber(amount))
            needsDebug(('%s used %s (%s +%.1f%%)'):format(tostring(_source), itemName, kind, amount))
        end)

        registered = registered + 1
    end

    for itemName, amount in pairs(items.Food or {}) do
        registerConsumable(itemName, amount, 'food')
    end

    for itemName, amount in pairs(items.Drink or {}) do
        registerConsumable(itemName, amount, 'drink')
    end

    needsDebug(('registered %d usable items'):format(registered))
end)


exports('consume', function(source, kind, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return false end

    kind = (kind == 'drink') and 'drink' or 'food'

    TriggerClientEvent('vn-hud:client:consume', source, kind, amount)
    return true
end)


exports('getPlayerNeeds', function(source)
    local values = needsCache[source]
    if not values then return nil end

    return { hunger = values.hunger, thirst = values.thirst }
end)
