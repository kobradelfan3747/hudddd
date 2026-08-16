local RESOURCE_NAME = GetCurrentResourceName()
local ORIGINAL_TEXTURE_DICTIONARY = 'platform:/textures/graphics'
local ORIGINAL_TEXTURE_NAME = 'radarmasksm'
local UNARMED_HASH = GetHashKey('WEAPON_UNARMED')

local WEAPON_LABELS = {
    [GetHashKey('WEAPON_UNARMED')] = 'Unarmed',
    [GetHashKey('WEAPON_KNIFE')] = 'Knife',
    [GetHashKey('WEAPON_NIGHTSTICK')] = 'Nightstick',
    [GetHashKey('WEAPON_HAMMER')] = 'Hammer',
    [GetHashKey('WEAPON_BAT')] = 'Baseball Bat',
    [GetHashKey('WEAPON_CROWBAR')] = 'Crowbar',
    [GetHashKey('WEAPON_GOLFCLUB')] = 'Golf Club',
    [GetHashKey('WEAPON_BOTTLE')] = 'Bottle',
    [GetHashKey('WEAPON_DAGGER')] = 'Dagger',
    [GetHashKey('WEAPON_HATCHET')] = 'Hatchet',
    [GetHashKey('WEAPON_MACHETE')] = 'Machete',
    [GetHashKey('WEAPON_SWITCHBLADE')] = 'Switchblade',
    [GetHashKey('WEAPON_FLASHLIGHT')] = 'Flashlight',
    [GetHashKey('WEAPON_KNUCKLE')] = 'Knuckle Duster',
    [GetHashKey('WEAPON_WRENCH')] = 'Wrench',
    [GetHashKey('WEAPON_BATTLEAXE')] = 'Battle Axe',
    [GetHashKey('WEAPON_POOLCUE')] = 'Pool Cue',
    [GetHashKey('WEAPON_STONE_HATCHET')] = 'Stone Hatchet',
    [GetHashKey('WEAPON_PISTOL')] = 'Pistol',
    [GetHashKey('WEAPON_PISTOL_MK2')] = 'Pistol Mk II',
    [GetHashKey('WEAPON_COMBATPISTOL')] = 'Combat Pistol',
    [GetHashKey('WEAPON_APPISTOL')] = 'AP Pistol',
    [GetHashKey('WEAPON_PISTOL50')] = 'Pistol .50',
    [GetHashKey('WEAPON_SNSPISTOL')] = 'SNS Pistol',
    [GetHashKey('WEAPON_SNSPISTOL_MK2')] = 'SNS Pistol Mk II',
    [GetHashKey('WEAPON_HEAVYPISTOL')] = 'Heavy Pistol',
    [GetHashKey('WEAPON_VINTAGEPISTOL')] = 'Vintage Pistol',
    [GetHashKey('WEAPON_MARKSMANPISTOL')] = 'Marksman Pistol',
    [GetHashKey('WEAPON_REVOLVER')] = 'Heavy Revolver',
    [GetHashKey('WEAPON_REVOLVER_MK2')] = 'Heavy Revolver Mk II',
    [GetHashKey('WEAPON_DOUBLEACTION')] = 'Double-Action Revolver',
    [GetHashKey('WEAPON_CERAMICPISTOL')] = 'Ceramic Pistol',
    [GetHashKey('WEAPON_NAVYREVOLVER')] = 'Navy Revolver',
    [GetHashKey('WEAPON_GADGETPISTOL')] = 'Perico Pistol',
    [GetHashKey('WEAPON_STUNGUN')] = 'Stun Gun',
    [GetHashKey('WEAPON_MICROSMG')] = 'Micro SMG',
    [GetHashKey('WEAPON_SMG')] = 'SMG',
    [GetHashKey('WEAPON_SMG_MK2')] = 'SMG Mk II',
    [GetHashKey('WEAPON_ASSAULTSMG')] = 'Assault SMG',
    [GetHashKey('WEAPON_COMBATPDW')] = 'Combat PDW',
    [GetHashKey('WEAPON_MACHINEPISTOL')] = 'Machine Pistol',
    [GetHashKey('WEAPON_MINISMG')] = 'Mini SMG',
    [GetHashKey('WEAPON_TECPISTOL')] = 'Tactical SMG',
    [GetHashKey('WEAPON_PUMPSHOTGUN')] = 'Pump Shotgun',
    [GetHashKey('WEAPON_PUMPSHOTGUN_MK2')] = 'Pump Shotgun Mk II',
    [GetHashKey('WEAPON_SAWNOFFSHOTGUN')] = 'Sawed-Off Shotgun',
    [GetHashKey('WEAPON_ASSAULTSHOTGUN')] = 'Assault Shotgun',
    [GetHashKey('WEAPON_BULLPUPSHOTGUN')] = 'Bullpup Shotgun',
    [GetHashKey('WEAPON_HEAVYSHOTGUN')] = 'Heavy Shotgun',
    [GetHashKey('WEAPON_DBSHOTGUN')] = 'Double Barrel Shotgun',
    [GetHashKey('WEAPON_AUTOSHOTGUN')] = 'Sweeper Shotgun',
    [GetHashKey('WEAPON_COMBATSHOTGUN')] = 'Combat Shotgun',
    [GetHashKey('WEAPON_ASSAULTRIFLE')] = 'Assault Rifle',
    [GetHashKey('WEAPON_ASSAULTRIFLE_MK2')] = 'Assault Rifle Mk II',
    [GetHashKey('WEAPON_CARBINERIFLE')] = 'Carbine Rifle',
    [GetHashKey('WEAPON_CARBINERIFLE_MK2')] = 'Carbine Rifle Mk II',
    [GetHashKey('WEAPON_ADVANCEDRIFLE')] = 'Advanced Rifle',
    [GetHashKey('WEAPON_SPECIALCARBINE')] = 'Special Carbine',
    [GetHashKey('WEAPON_SPECIALCARBINE_MK2')] = 'Special Carbine Mk II',
    [GetHashKey('WEAPON_BULLPUPRIFLE')] = 'Bullpup Rifle',
    [GetHashKey('WEAPON_BULLPUPRIFLE_MK2')] = 'Bullpup Rifle Mk II',
    [GetHashKey('WEAPON_COMPACTRIFLE')] = 'Compact Rifle',
    [GetHashKey('WEAPON_MILITARYRIFLE')] = 'Military Rifle',
    [GetHashKey('WEAPON_HEAVYRIFLE')] = 'Heavy Rifle',
    [GetHashKey('WEAPON_TACTICALRIFLE')] = 'Service Carbine',
    [GetHashKey('WEAPON_MG')] = 'MG',
    [GetHashKey('WEAPON_COMBATMG')] = 'Combat MG',
    [GetHashKey('WEAPON_COMBATMG_MK2')] = 'Combat MG Mk II',
    [GetHashKey('WEAPON_GUSENBERG')] = 'Gusenberg Sweeper',
    [GetHashKey('WEAPON_SNIPERRIFLE')] = 'Sniper Rifle',
    [GetHashKey('WEAPON_HEAVYSNIPER')] = 'Heavy Sniper',
    [GetHashKey('WEAPON_HEAVYSNIPER_MK2')] = 'Heavy Sniper Mk II',
    [GetHashKey('WEAPON_MARKSMANRIFLE')] = 'Marksman Rifle',
    [GetHashKey('WEAPON_MARKSMANRIFLE_MK2')] = 'Marksman Rifle Mk II',
    [GetHashKey('WEAPON_PRECISIONRIFLE')] = 'Precision Rifle',
    [GetHashKey('WEAPON_GRENADELAUNCHER')] = 'Grenade Launcher',
    [GetHashKey('WEAPON_RPG')] = 'RPG',
    [GetHashKey('WEAPON_MINIGUN')] = 'Minigun',
    [GetHashKey('WEAPON_FIREWORK')] = 'Firework Launcher',
    [GetHashKey('WEAPON_RAILGUN')] = 'Railgun',
    [GetHashKey('WEAPON_HOMINGLAUNCHER')] = 'Homing Launcher',
    [GetHashKey('WEAPON_COMPACTLAUNCHER')] = 'Compact Launcher',
    [GetHashKey('WEAPON_GRENADE')] = 'Grenade',
    [GetHashKey('WEAPON_STICKYBOMB')] = 'Sticky Bomb',
    [GetHashKey('WEAPON_SMOKEGRENADE')] = 'Tear Gas',
    [GetHashKey('WEAPON_MOLOTOV')] = 'Molotov',
    [GetHashKey('WEAPON_FIREEXTINGUISHER')] = 'Fire Extinguisher',
    [GetHashKey('WEAPON_PETROLCAN')] = 'Jerry Can',
    [GetHashKey('WEAPON_FLARE')] = 'Flare',
    [GetHashKey('WEAPON_BALL')] = 'Ball'
}

local state = {
    textureApplied = false,
    northBlipHidden = false,
    minimapScaleform = nil,
    statusVisible = nil,
    playerPanelVisible = nil,
    compassVisible = nil,
    hudReady = false,
    screenSignature = nil,
    refreshGeneration = 0,
    applyingMinimap = false,
    sessionActive = false,
    monitoredServerId = 0,
    monitoredPed = 0,
    lastMinimapApply = 0,
    internalBigmapRefresh = false,
    esx = nil,
    playerData = {},
    databaseName = nil,
    databaseCash = nil,
    databaseBank = nil,
    databaseGroup = nil,
    databaseProfileLoaded = false,
    lastProfileRequest = 0,
    lastPlayerInfoKey = nil,
    lastHeading = -1000.0,
    values = {
        health = 100,
        water = Config.Status.FallbackValue,
        food = Config.Status.FallbackValue,
        stamina = 100
    },
    lastSentValues = {}
}

local function debugPrint(_)
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function toWholeNumber(value)
    value = tonumber(value)

    -- Protect the HUD and its JSON payload from invalid framework/database values.
    if value == nil or value ~= value or value == math.huge or value == -math.huge then
        return 0
    end

    return math.floor(value)
end

local function getUltrawideOffset()
    if not Config.Minimap.Ultrawide.Enabled then
        return 0.0
    end

    local reference = Config.Minimap.Ultrawide.ReferenceAspectRatio
    local aspectRatio = GetAspectRatio(false)

    if aspectRatio <= reference then
        return 0.0
    end

    return (reference - aspectRatio) / Config.Minimap.Ultrawide.OffsetDivisor
end

local function setComponentPosition(componentName, component, xOffset, moveUp)
    SetMinimapComponentPosition(
        componentName,
        component.alignX,
        component.alignY,
        component.x + xOffset,
        component.y - moveUp,
        component.width,
        component.height
    )
end

local function applyMinimapPosition()
    local position = Config.Minimap.Position
    local xOffset = getUltrawideOffset()
    local moveUp = Config.Minimap.MoveUp

    setComponentPosition('minimap', position.Minimap, xOffset, moveUp)
    setComponentPosition('minimap_mask', position.Mask, xOffset, moveUp)
    setComponentPosition('minimap_blur', position.Blur, xOffset, moveUp)
end

local function restoreDefaultPosition()
    local position = Config.Minimap.Position

    setComponentPosition('minimap', position.Minimap, 0.0, 0.0)
    setComponentPosition('minimap_mask', position.Mask, 0.0, 0.0)
    setComponentPosition('minimap_blur', position.Blur, 0.0, 0.0)
end

local function refreshMinimapScaleform()
    state.internalBigmapRefresh = true
    SetRadarBigmapEnabled(false, false)
    SetRadarBigmapEnabled(true, false)
    Wait(0)
    SetRadarBigmapEnabled(false, false)
    state.internalBigmapRefresh = false
end

local function getScreenSignature()
    local resolutionX, resolutionY = GetActiveScreenResolution()
    return ('%d:%d:%.4f:%.4f'):format(
        resolutionX,
        resolutionY,
        GetSafeZoneSize(),
        GetAspectRatio(false)
    )
end

local function getHudLayout()
    local safeZone = clamp(GetSafeZoneSize(), 0.9, 1.0)
    local resolutionX, resolutionY = GetActiveScreenResolution()
    resolutionX = math.max(1, resolutionX)
    resolutionY = math.max(1, resolutionY)

    local aspectRatio = resolutionX / resolutionY
    local safeInset = math.abs(safeZone - 1.0) * 0.5
    local minimapWidth = 1.0 / (4.0 * aspectRatio)
    local minimapHeight = Config.Minimap.Position.Minimap.height
    local minimapBottom = 1.0 - safeInset - Config.Minimap.MoveUp
    local minimapTop = minimapBottom - minimapHeight

    return {
        statusLeft = (safeInset * resolutionX) + Config.Status.OffsetX,
        statusTop = ((minimapBottom + Config.Status.GapY) * resolutionY) + Config.Status.OffsetY,
        statusWidth = (minimapWidth * resolutionX) + Config.Status.WidthAdjustment,
        playerTop = (safeInset * resolutionY) + Config.PlayerInfo.OffsetTop,
        playerRight = (safeInset * resolutionX) + Config.PlayerInfo.OffsetRight,
        compassTop = (Config.Compass.AttachToScreenTop and 0 or (safeInset * resolutionY)) + Config.Compass.OffsetTop,
        minimapHeight = minimapHeight * resolutionY,
        radioLeft = (safeInset * resolutionX) + Config.Status.OffsetX,
        radioWidth = (minimapWidth * resolutionX) + Config.Status.WidthAdjustment,
        radioBottom = ((1.0 - minimapTop) * resolutionY) + (tonumber(Config.Radio and Config.Radio.PanelLift) or 108)
    }
end

local function sendHudLayout()
    SendNUIMessage({
        action = 'hud:layout',
        layout = getHudLayout(),
        style = {
            statusBackground = Config.Status.BackgroundColor,
            panelAccent = Config.PlayerInfo.AccentColor,
            compassAccent = Config.Compass.AccentColor,
            health = Config.Status.HealthColor,
            healthEnd = Config.Status.HealthColorEnd,
            water = Config.Status.WaterColor,
            waterEnd = Config.Status.WaterColorEnd,
            food = Config.Status.FoodColor,
            foodEnd = Config.Status.FoodColorEnd,
            stamina = Config.Status.StaminaColor,
            staminaEnd = Config.Status.StaminaColorEnd
        }
    })
end


local function enforceMinimapSilently()
    if not Config.Minimap.Enabled then return true end

    local texture = Config.Minimap.Texture
    if not HasStreamedTextureDictLoaded(texture.Dictionary) then
        return false
    end

    SetMinimapClipType(0)
    AddReplaceTexture(
        ORIGINAL_TEXTURE_DICTIONARY,
        ORIGINAL_TEXTURE_NAME,
        texture.Dictionary,
        texture.Name
    )
    applyMinimapPosition()

    if Config.Minimap.HideNorthBlip then
        SetBlipAlpha(GetNorthRadarBlip(), 0)
        state.northBlipHidden = true
    end

    state.textureApplied = true
    state.lastMinimapApply = GetGameTimer()
    sendHudLayout()
    return true
end

local function setStatusVisible(visible)
    visible = visible == true
    if state.statusVisible == visible then
        return
    end

    state.statusVisible = visible
    SendNUIMessage({ action = 'status:visibility', visible = visible })
end

local function setUpperVisible(visible)
    local playerVisible = visible == true and Config.PlayerInfo.Enabled
    local compassVisible = visible == true and Config.Compass.Enabled

    if state.playerPanelVisible == playerVisible and state.compassVisible == compassVisible then
        return
    end

    state.playerPanelVisible = playerVisible
    state.compassVisible = compassVisible
    SendNUIMessage({
        action = 'upper:visibility',
        player = playerVisible,
        compass = compassVisible
    })
end

local function sendStatusValues(force)
    if not Config.Status.Enabled then
        return
    end

    local changed = force == true
    for name, value in pairs(state.values) do
        if state.lastSentValues[name] ~= value then
            changed = true
            break
        end
    end

    if not changed then
        return
    end

    for name, value in pairs(state.values) do
        state.lastSentValues[name] = value
    end

    SendNUIMessage({ action = 'status:values', values = state.values })
end

local function setStatusValue(name, value)
    state.values[name] = math.floor(clamp(tonumber(value) or 0, 0, 100) + 0.5)
end

local function extractStatusPercent(status)
    if type(status) ~= 'table' then
        return nil
    end

    if type(status.getPercent) == 'function' then
        local ok, value = pcall(status.getPercent)
        if not ok then
            ok, value = pcall(status.getPercent, status)
        end
        if ok and tonumber(value) then
            return tonumber(value)
        end
    end

    if tonumber(status.percent) then
        return tonumber(status.percent)
    end

    if tonumber(status.val) then
        local value = tonumber(status.val)
        local maximum = tonumber(status.max) or 1000000

        if maximum > 0 and value > 100 then
            return (value / maximum) * 100
        end

        return value
    end

    return nil
end

local function requestESXStatus(statusName, targetName)

    local answered = false

    TriggerEvent('esx_status:getStatus', statusName, function(status)
        local percentage = extractStatusPercent(status)
        if percentage then
            answered = true
            setStatusValue(targetName, percentage)
            sendStatusValues(false)
        end
    end)

    if answered then
        return
    end


    local ok, percentage = pcall(function()
        return exports[Config.Status.ESXStatusResource]:getPercent(statusName)
    end)

    if ok and tonumber(percentage) then
        setStatusValue(targetName, tonumber(percentage))
        sendStatusValues(false)
    end
end

local function updatePlayerValues()
    local ped = PlayerPedId()
    local currentHealth = math.max(0, GetEntityHealth(ped) - 100)
    local maximumHealth = math.max(1, GetEntityMaxHealth(ped) - 100)
    local stamina = GetPlayerSprintStaminaRemaining(PlayerId())

    if stamina == nil or stamina < 0 then
        stamina = 100
    end

    setStatusValue('health', (currentHealth / maximumHealth) * 100.0)
    setStatusValue('stamina', stamina)
    sendStatusValues(false)
end

local function refreshESX()
    if GetResourceState('es_extended') ~= 'started' then
        state.esx = nil
        return
    end

    if not state.esx then
        local ok, object = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)

        if ok and object then
            state.esx = object
        else
            TriggerEvent('esx:getSharedObject', function(sharedObject)
                state.esx = sharedObject
            end)
        end
    end

    if state.esx and type(state.esx.GetPlayerData) == 'function' then
        local ok, playerData = pcall(state.esx.GetPlayerData)
        if ok and type(playerData) == 'table' and next(playerData) then
            state.playerData = playerData
        end
    end
end

local function getPlayerDisplayName()
    if Config.PlayerInfo.NameSource == 'database' then
        return state.databaseName or GetPlayerName(PlayerId()) or 'Player'
    end

    if Config.PlayerInfo.NameSource == 'game' then
        return GetPlayerName(PlayerId()) or 'Player'
    end

    local data = state.playerData or {}
    local variables = type(data.variables) == 'table' and data.variables or {}
    local firstName = data.firstName or data.firstname or variables.firstName or variables.firstname
    local lastName = data.lastName or data.lastname or variables.lastName or variables.lastname

    if firstName or lastName then
        return (('%s %s'):format(firstName or '', lastName or '')):gsub('^%s+', ''):gsub('%s+$', '')
    end

    if type(data.name) == 'string' and data.name ~= '' then
        return data.name
    end

    return GetPlayerName(PlayerId()) or 'Player'
end

local function getPlayerJobLabel()
    local job = type(state.playerData.job) == 'table' and state.playerData.job or nil
    if not job then
        return Config.PlayerInfo.FallbackJob
    end

    local label = job.label or job.name or Config.PlayerInfo.FallbackJob
    local grade = job.grade_label or job.gradeLabel or job.grade_name or job.gradeName
    if (type(grade) ~= 'string' or grade == '') and type(job.grade) == 'table' then
        grade = job.grade.label or job.grade.grade_label or job.grade.name or job.grade.grade_name
    end

    if Config.PlayerInfo.ShowJobGrade and type(grade) == 'string' and grade ~= '' then
        return ('%s  •  %s'):format(label, grade)
    end

    return label
end

local function getPlayerGangLabel()
    local data = state.playerData or {}
    local metadata = type(data.metadata) == 'table' and data.metadata or {}
    local gang = data.gang or data.job2 or metadata.gang

    if type(gang) == 'string' and gang ~= '' then
        return gang
    end

    if type(gang) ~= 'table' then
        local label = data.gang_label or data.gangLabel or data.gang_name or data.gangName
        return type(label) == 'string' and label ~= '' and label or Config.PlayerInfo.FallbackGang
    end

    local label = gang.label or gang.name or Config.PlayerInfo.FallbackGang
    local grade = gang.grade_label or gang.gradeLabel or gang.grade_name or gang.gradeName

    if Config.PlayerInfo.ShowGangGrade and type(grade) == 'string' and grade ~= '' then
        return ('%s  •  %s'):format(label, grade)
    end

    return label
end

local function getAccountMoney(accountName)
    local data = state.playerData or {}
    local accounts = data.accounts


    if type(accounts) == 'string' and accounts ~= '' then
        local ok, decoded = pcall(json.decode, accounts)
        if ok and type(decoded) == 'table' then accounts = decoded end
    end


    if type(accounts) == 'table' then
        local directAccount = accounts[accountName]
        if directAccount ~= nil then
            if type(directAccount) == 'table' then
                return toWholeNumber(directAccount.money or directAccount.amount or directAccount.value)
            end

            if tonumber(directAccount) ~= nil then
                return toWholeNumber(directAccount)
            end
        end

        for _, account in pairs(accounts) do
            if type(account) == 'table' and (account.name == accountName or account.account == accountName) then
                return toWholeNumber(account.money or account.amount or account.value)
            end
        end
    end

    if accountName == 'money' then
        if tonumber(data.money) ~= nil then return toWholeNumber(data.money) end
        if tonumber(data.cash) ~= nil then return toWholeNumber(data.cash) end
        if state.databaseCash ~= nil then return toWholeNumber(state.databaseCash) end
    elseif accountName == 'bank' and state.databaseBank ~= nil then
        return toWholeNumber(state.databaseBank)
    end

    return 0
end

local function getWeaponDataFromESX(weaponHash)
    if not state.esx then
        return nil, nil
    end

    local getWeapon = state.esx.GetWeaponFromHash or state.esx.GetWeaponFromhash
    if type(getWeapon) == 'function' then
        local ok, first, second = pcall(getWeapon, weaponHash)
        if ok then
            local weapon = type(second) == 'table' and second or (type(first) == 'table' and first or nil)
            if weapon then
                local weaponName = type(weapon.name) == 'string' and string.upper(weapon.name) or nil
                return weapon.label or weaponName, weaponName
            end
        end
    end

    local loadout = state.playerData and state.playerData.loadout
    if type(loadout) == 'table' then
        for _, weapon in pairs(loadout) do
            if type(weapon) == 'table' and weapon.name and GetHashKey(weapon.name) == weaponHash then
                local weaponName = string.upper(weapon.name)
                return weapon.label or weaponName, weaponName
            end
        end
    end

    return nil, nil
end

local function getCurrentWeaponInfo()
    local ped = PlayerPedId()
    local weaponHash = GetSelectedPedWeapon(ped)
    local armed = weaponHash ~= UNARMED_HASH and IsPedArmed(ped, 4)

    if not armed then
        return Config.PlayerInfo.UnarmedLabel, '--', false, nil
    end

    local esxLabel, esxWeaponName = getWeaponDataFromESX(weaponHash)
    local label = esxLabel or WEAPON_LABELS[weaponHash] or Config.PlayerInfo.UnknownWeaponLabel
    local imageName = esxWeaponName or (VN_WEAPON_IMAGES and VN_WEAPON_IMAGES[weaponHash])
    local totalAmmo = math.max(0, GetAmmoInPedWeapon(ped, weaponHash))
    local hasClip, clipAmmo = GetAmmoInClip(ped, weaponHash)
    local ammoText = '--'

    if hasClip and tonumber(clipAmmo) then
        clipAmmo = math.max(0, tonumber(clipAmmo))
        local reserveAmmo = math.max(0, totalAmmo - clipAmmo)
        ammoText = ('%d / %d'):format(clipAmmo, reserveAmmo)
    elseif totalAmmo > 0 then
        ammoText = tostring(totalAmmo)
    elseif IsPedArmed(ped, 4) then
        ammoText = '0 / 0'
    end

    return label, ammoText, true, imageName
end

local function sendPlayerInfo(force)
    if not Config.PlayerInfo.Enabled then
        return
    end

    local weaponName, ammo, armed, weaponImage = getCurrentWeaponInfo()
    local info = {
        serverId = GetPlayerServerId(PlayerId()),
        job = getPlayerJobLabel(),
        gang = getPlayerGangLabel(),
        cash = getAccountMoney('money'),
        currencySymbol = Config.PlayerInfo.CurrencySymbol,
        weaponName = weaponName,
        weaponImage = weaponImage,
        ammo = ammo,
        armed = armed
    }
    -- Use strings for the cache key because Lua's %d conversion rejects any
    -- numeric account value that has no native integer representation.
    local key = table.concat({
        tostring(info.serverId or ''),
        tostring(info.job or ''),
        tostring(info.gang or ''),
        tostring(info.cash or ''),
        tostring(info.weaponName or ''),
        tostring(info.weaponImage or ''),
        tostring(info.ammo or ''),
        tostring(info.armed)
    }, '\31')

    if not force and key == state.lastPlayerInfoKey then
        return
    end

    state.lastPlayerInfoKey = key
    SendNUIMessage({ action = 'player:info', info = info })
end

local function sendCompassHeading(force)
    if not Config.Compass.Enabled then
        return
    end

    local cameraRotation = GetGameplayCamRot(0)
    local heading = 360.0 - ((cameraRotation.z + 360.0) % 360.0)
    heading = heading % 360.0

    local difference = math.abs(heading - state.lastHeading)
    difference = math.min(difference, 360.0 - difference)

    if not force and difference < 0.2 then
        return
    end

    state.lastHeading = heading
    SendNUIMessage({
        action = 'compass:heading',
        heading = heading,
        fieldOfView = Config.Compass.FieldOfView
    })
end

local function applyRoundedRectangleMask()
    if not Config.Minimap.Enabled or state.applyingMinimap then
        return false
    end

    state.applyingMinimap = true
    local texture = Config.Minimap.Texture
    RequestStreamedTextureDict(texture.Dictionary, false)

    local timeoutAt = GetGameTimer() + Config.Minimap.TextureLoadTimeout
    while not HasStreamedTextureDictLoaded(texture.Dictionary) do
        if GetGameTimer() >= timeoutAt then
            state.applyingMinimap = false
            return false
        end
        Wait(50)
    end

    SetRadarBigmapEnabled(false, false)
    SetMinimapClipType(0)
    AddReplaceTexture(
        ORIGINAL_TEXTURE_DICTIONARY,
        ORIGINAL_TEXTURE_NAME,
        texture.Dictionary,
        texture.Name
    )

    applyMinimapPosition()

    if Config.Minimap.HideNorthBlip then
        SetBlipAlpha(GetNorthRadarBlip(), 0)
        state.northBlipHidden = true
    end

    refreshMinimapScaleform()
    state.textureApplied = true
    state.screenSignature = getScreenSignature()
    state.hudReady = true
    state.lastMinimapApply = GetGameTimer()

    state.statusVisible = nil
    state.playerPanelVisible = nil
    state.compassVisible = nil
    state.applyingMinimap = false

    sendHudLayout()
    updatePlayerValues()
    sendStatusValues(true)
    sendPlayerInfo(true)
    sendCompassHeading(true)

    if Config.PlayerInfo.NameSource == 'database'
        and (not state.databaseName or not state.databaseProfileLoaded)
        and GetGameTimer() - state.lastProfileRequest >= Config.Identity.RetryInterval then
        state.lastProfileRequest = GetGameTimer()
        TriggerServerEvent('vn-hud:server:requestProfile', not state.databaseProfileLoaded)
    end

    debugPrint('Minimap and complete HUD safely reapplied for the current session.')
    return true
end

local function scheduleSessionRefresh(reason)
    state.refreshGeneration = state.refreshGeneration + 1
    local generation = state.refreshGeneration

    debugPrint(('Scheduled minimap refresh: %s'):format(reason or 'unknown'))

    CreateThread(function()
        local previousDelay = 0

        for _, targetDelay in ipairs(Config.Minimap.SessionRefreshDelays) do
            Wait(math.max(0, targetDelay - previousDelay))
            previousDelay = targetDelay

            if generation ~= state.refreshGeneration then
                return
            end

            if NetworkIsSessionStarted() then
                applyRoundedRectangleMask()
            end
        end
    end)
end

local function restoreDefaultMinimap()
    if state.northBlipHidden then
        SetBlipAlpha(GetNorthRadarBlip(), 255)
        state.northBlipHidden = false
    end

    if state.textureApplied then
        RemoveReplaceTexture(ORIGINAL_TEXTURE_DICTIONARY, ORIGINAL_TEXTURE_NAME)
        SetStreamedTextureDictAsNoLongerNeeded(Config.Minimap.Texture.Dictionary)
        state.textureApplied = false
    end

    SetRadarBigmapEnabled(false, false)
    SetMinimapClipType(0)
    restoreDefaultPosition()
end


CreateThread(function()
    if not Config.Minimap.Enabled or not Config.Minimap.HideVanillaHealthArmour then
        return
    end

    while Config.Minimap.Enabled and Config.Minimap.HideVanillaHealthArmour do
        if not state.minimapScaleform or not HasScaleformMovieLoaded(state.minimapScaleform) then
            state.minimapScaleform = RequestScaleformMovie('minimap')
            Wait(50)
        else
            BeginScaleformMovieMethod(state.minimapScaleform, 'SETUP_HEALTH_ARMOUR')
            ScaleformMovieMethodAddParamInt(3)
            EndScaleformMovieMethod()
            Wait(0)
        end
    end
end)


CreateThread(function()
    if not Config.PlayerInfo.HideDefaultCashHud then
        return
    end

    while Config.PlayerInfo.HideDefaultCashHud do
        HideHudComponentThisFrame(3)
        HideHudComponentThisFrame(4)
        HideHudComponentThisFrame(13)
        Wait(0)
    end
end)

CreateThread(function()
    while Config.Status.Enabled do
        Wait(Config.Status.PlayerUpdateInterval)
        updatePlayerValues()
    end
end)

CreateThread(function()
    if Config.Status.DisableHealthRegen == false then
        return
    end

    while true do
        local player = PlayerId()
        pcall(SetPlayerHealthRechargeMultiplier, player, 0.0)
        pcall(function()
            SetPlayerHealthRechargeLimit(player, 0.0)
        end)
        Wait(400)
    end
end)

CreateThread(function()

    local useInternal = Config.Needs
        and Config.Needs.Enabled
        and not Config.Needs.UseExternalStatus

    while Config.Status.Enabled do
        Wait(Config.Status.NeedsUpdateInterval)

        if useInternal then

            local ok, values = pcall(function()
                return exports['vn-hud']:getNeeds()
            end)

            if ok and type(values) == 'table' then
                if tonumber(values.thirst) then
                    setStatusValue('water', tonumber(values.thirst))
                end
                if tonumber(values.hunger) then
                    setStatusValue('food', tonumber(values.hunger))
                end
                sendStatusValues(false)
            end

        elseif GetResourceState(Config.Status.ESXStatusResource) == 'started' then

            requestESXStatus(Config.Status.ThirstStatusName, 'water')
            requestESXStatus(Config.Status.HungerStatusName, 'food')
        end
    end
end)

CreateThread(function()
    while Config.PlayerInfo.Enabled do
        Wait(Config.PlayerInfo.UpdateInterval)
        if state.hudReady then
            sendPlayerInfo(false)
        end
    end
end)

CreateThread(function()
    while Config.PlayerInfo.Enabled do
        refreshESX()
        Wait(Config.PlayerInfo.ESXRefreshInterval)
    end
end)

CreateThread(function()
    while Config.Compass.Enabled do
        Wait(Config.Compass.UpdateInterval)
        if state.hudReady then
            sendCompassHeading(false)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.Status.VisibilityInterval)

        local visible = state.hudReady
        visible = visible and (not Config.Status.HideOnPause or not IsPauseMenuActive())
        visible = visible and (state.internalBigmapRefresh or not IsBigmapActive())

        local statusVisible = visible
        if Config.Status.HideWithRadar then
            statusVisible = statusVisible and not IsRadarHidden()
        end

        setStatusVisible(statusVisible and Config.Status.Enabled)
        setUpperVisible(visible)
    end
end)

CreateThread(function()
    while true do
        Wait(Config.Status.LayoutCheckInterval)

        if state.textureApplied then
            local signature = getScreenSignature()
            if signature ~= state.screenSignature then
                applyMinimapPosition()
                refreshMinimapScaleform()
                state.screenSignature = signature
                sendHudLayout()
            end
        end
    end
end)


CreateThread(function()
    while true do
        Wait(500)

        local active = NetworkIsSessionStarted() and NetworkIsPlayerActive(PlayerId())
        local serverId = active and GetPlayerServerId(PlayerId()) or 0
        local ped = active and PlayerPedId() or 0

        if active then
            local newSession = not state.sessionActive or serverId ~= state.monitoredServerId
            local newPed = ped ~= 0 and ped ~= state.monitoredPed

            if newSession or newPed then
                state.sessionActive = true
                state.monitoredServerId = serverId
                state.monitoredPed = ped
                state.refreshGeneration = state.refreshGeneration + 1
                scheduleSessionRefresh(newSession and 'server session changed' or 'player ped changed')

                if newSession and Config.PlayerInfo.NameSource == 'database' then
                    state.databaseName = nil
                    state.databaseCash = nil
                    state.databaseBank = nil
                    state.databaseGroup = nil
                    state.databaseProfileLoaded = false
                    state.lastProfileRequest = GetGameTimer()
                    state.lastPlayerInfoKey = nil
                    TriggerServerEvent('vn-hud:server:requestProfile', true)
                end
            end

            if not state.internalBigmapRefresh
                and not Config.Minimap.AllowExpandedRadar
                and not IsPauseMenuActive()
                and IsBigmapActive() then
                SetRadarBigmapEnabled(false, false)
                applyMinimapPosition()
                sendHudLayout()
            end

            if not IsPauseMenuActive()
                and GetGameTimer() - state.lastMinimapApply >= Config.Minimap.WatchdogInterval then
                if not enforceMinimapSilently() then
                    scheduleSessionRefresh('watchdog texture reload')
                end
            end
        elseif state.sessionActive then
            state.sessionActive = false
            state.monitoredServerId = 0
            state.monitoredPed = 0
            state.hudReady = false
            state.databaseName = nil
            state.databaseCash = nil
            state.databaseBank = nil
            state.databaseGroup = nil
            state.databaseProfileLoaded = false
            state.lastProfileRequest = 0
            state.playerData = {}
            state.lastPlayerInfoKey = nil
            state.refreshGeneration = state.refreshGeneration + 1
            setStatusVisible(false)
            setUpperVisible(false)
            SetRadarBigmapEnabled(false, false)
        end
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == RESOURCE_NAME then
        refreshESX()
        scheduleSessionRefresh('resource start')
    elseif resourceName == 'es_extended' then
        refreshESX()
    end
end)

AddEventHandler('playerSpawned', function()
    scheduleSessionRefresh('player spawned')
end)

AddEventHandler('onClientMapStart', function()
    state.lastMinimapApply = 0
    scheduleSessionRefresh('client map started')
end)

local function applyDatabaseProfile(profile)
    if type(profile) ~= 'table' then return end

    if type(profile.fullName) == 'string' and profile.fullName ~= '' then
        state.databaseName = profile.fullName
    end
    if profile.cash ~= nil then state.databaseCash = tonumber(profile.cash) or 0 end
    if profile.bank ~= nil then state.databaseBank = tonumber(profile.bank) or 0 end
    if profile.group ~= nil then state.databaseGroup = tostring(profile.group) end
    state.databaseProfileLoaded = profile.fromDatabase == true

    state.lastPlayerInfoKey = nil
    sendPlayerInfo(true)
end

RegisterNetEvent('vn-hud:client:setProfile', applyDatabaseProfile)
RegisterNetEvent('vn-hud:client:setIdentity', applyDatabaseProfile)

RegisterNetEvent('esx:playerLoaded', function(playerData)
    if type(playerData) == 'table' then
        state.playerData = playerData
    end
    state.lastPlayerInfoKey = nil
    state.databaseName = nil
    state.databaseCash = nil
    state.databaseBank = nil
    state.databaseGroup = nil
    state.databaseProfileLoaded = false
    state.lastProfileRequest = GetGameTimer()
    TriggerServerEvent('vn-hud:server:requestProfile', true)
    scheduleSessionRefresh('ESX player loaded')
end)

RegisterNetEvent('esx:setJob', function(job)
    if type(job) == 'table' then
        state.playerData.job = job
        state.lastPlayerInfoKey = nil
        sendPlayerInfo(true)
    end
end)

local function updateGang(gang)
    if type(gang) == 'table' or type(gang) == 'string' then
        state.playerData.gang = gang
        state.lastPlayerInfoKey = nil
        sendPlayerInfo(true)
    end
end

RegisterNetEvent('esx:setGang', updateGang)
RegisterNetEvent('gang:setGang', updateGang)
RegisterNetEvent('vn-hud:client:setGang', updateGang)

RegisterNetEvent('esx:setAccountMoney', function(account)
    if type(account) ~= 'table' or type(account.name) ~= 'string' then
        return
    end

    state.playerData.accounts = type(state.playerData.accounts) == 'table' and state.playerData.accounts or {}
    local updated = false

    for key, currentAccount in pairs(state.playerData.accounts) do
        if type(currentAccount) == 'table' and currentAccount.name == account.name then
            state.playerData.accounts[key] = account
            updated = true
            break
        end
    end

    if not updated then
        state.playerData.accounts[account.name] = account
    end

    local accountValue = tonumber(account.money or account.amount) or 0
    if account.name == 'money' then
        state.playerData.money = accountValue
        state.databaseCash = accountValue
    elseif account.name == 'bank' then
        state.databaseBank = accountValue
    end

    state.lastPlayerInfoKey = nil
    sendPlayerInfo(true)
end)

RegisterNetEvent('esx:setPlayerData', function(key, value)
    if type(key) == 'string' then
        state.playerData[key] = value
        state.lastPlayerInfoKey = nil
    end
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    state.playerData = {}
    state.databaseName = nil
    state.databaseCash = nil
    state.databaseBank = nil
    state.databaseGroup = nil
    state.databaseProfileLoaded = false
    state.lastProfileRequest = 0
    state.hudReady = false
    state.refreshGeneration = state.refreshGeneration + 1
    state.lastPlayerInfoKey = nil
    setStatusVisible(false)
    setUpperVisible(false)
    SetRadarBigmapEnabled(false, false)
end)

AddEventHandler('esx_status:onTick', function(statuses)
    if type(statuses) ~= 'table' then
        return
    end


    if Config.Needs and Config.Needs.Enabled and not Config.Needs.UseExternalStatus then
        return
    end

    for _, status in pairs(statuses) do
        if type(status) == 'table' then
            local percentage = extractStatusPercent(status)
            if percentage and status.name == Config.Status.ThirstStatusName then
                setStatusValue('water', percentage)
            elseif percentage and status.name == Config.Status.HungerStatusName then
                setStatusValue('food', percentage)
            end
        end
    end

    sendStatusValues(false)
end)

RegisterNetEvent('vn-hud:client:refreshMinimap', function()
    scheduleSessionRefresh('manual event')
end)

exports('RefreshMinimap', function()
    scheduleSessionRefresh('manual export')
    return true
end)

RegisterNUICallback('vnHudReady', function(_, cb)
    state.statusVisible = nil
    state.playerPanelVisible = nil
    state.compassVisible = nil

    sendHudLayout()
    sendStatusValues(true)
    sendPlayerInfo(true)
    sendCompassHeading(true)

    local visible = state.hudReady
        and not IsPauseMenuActive()
        and (state.internalBigmapRefresh or not IsBigmapActive())
    local statusVisible = visible and Config.Status.Enabled
    if Config.Status.HideWithRadar then statusVisible = statusVisible and not IsRadarHidden() end

    setStatusVisible(statusVisible)
    setUpperVisible(visible)

    if Config.PlayerInfo.NameSource == 'database' and not state.databaseProfileLoaded then
        state.lastProfileRequest = GetGameTimer()
        TriggerServerEvent('vn-hud:server:requestProfile', true)
    end

    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= RESOURCE_NAME then
        return
    end

    state.hudReady = false
    setStatusVisible(false)
    setUpperVisible(false)

    if Config.Minimap.RestoreDefaultOnStop then
        restoreDefaultMinimap()
    end

    if state.minimapScaleform then
        SetScaleformMovieAsNoLongerNeeded(state.minimapScaleform)
        state.minimapScaleform = nil
    end
end)
