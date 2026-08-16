(() => {
    'use strict';

    const root = document.documentElement;
    const statusHud = document.getElementById('status-hud');
    const playerPanel = document.getElementById('player-panel');
    const compass = document.getElementById('compass');
    const compassTrack = document.getElementById('compass-track');
    const compassHeading = document.getElementById('compass-heading');
    const playerName = document.getElementById('player-name');
    const playerJob = document.getElementById('player-job');
    const playerGang = document.getElementById('player-gang');
    const playerCash = document.getElementById('player-cash');
    const weaponRow = document.getElementById('weapon-row');
    const weaponName = document.getElementById('weapon-name');
    const weaponAmmo = document.getElementById('weapon-ammo');
    const weaponImage = document.getElementById('weapon-image');
    const chatShell = document.getElementById('chat-shell');
    const chatMessages = document.getElementById('chat-messages');
    const chatSuggestions = document.getElementById('chat-suggestions');
    const chatInput = document.getElementById('chat-input');
    const chatCounter = document.getElementById('chat-counter');
    const emojiButton = document.getElementById('emoji-button');
    const emojiPicker = document.getElementById('emoji-picker');
    const voiceWidget = document.getElementById('voice-widget');
    const voiceBars = document.getElementById('voice-bars');
    const vehicleHud = document.getElementById('vehicle-hud');
    const vehicleSpeedPanel = document.getElementById('vehicle-speed-panel');
    const vehicleRpmRail = document.getElementById('vehicle-rpm-rail');
    const vehicleSpeed = document.getElementById('vehicle-speed');
    const vehicleUnit = document.getElementById('vehicle-unit');
    const vehicleTrip = document.getElementById('vehicle-trip');
    const vehicleFuel = document.getElementById('vehicle-fuel');
    const vehicleFuelFill = document.getElementById('vehicle-fuel-fill');
    const vehicleEngine = document.getElementById('vehicle-engine');
    const vehicleEngineFill = document.getElementById('vehicle-engine-fill');
    const vehicleGear = document.getElementById('vehicle-gear');
    const vehicleRpmFill = document.getElementById('vehicle-rpm-fill');
    const vehicleIgnition = document.getElementById('vehicle-ignition');
    const vehicleSeatbelt = document.getElementById('vehicle-seatbelt');
    const vehicleLights = document.getElementById('vehicle-lights');
    const vehicleLock = document.getElementById('vehicle-lock');
    const seatbeltAudio = document.getElementById('seatbelt-audio');
    const vehicleLeftSignal = document.querySelector('[data-vehicle-indicator="left"]');
    const vehicleRightSignal = document.querySelector('[data-vehicle-indicator="right"]');
    const radioPanel = document.getElementById('radio-panel');
    const radioList = document.getElementById('radio-list');
    const radioNow = document.getElementById('radio-now');
    const radioSub = document.getElementById('radio-sub');
    const radioClose = document.getElementById('radio-close');
    const radioVolume = document.getElementById('radio-volume');
    const radioVolNum = document.getElementById('radio-vol-num');
    const radioAudio = document.getElementById('radio-audio');

    const statusElements = new Map(
        [...document.querySelectorAll('[data-status]')].map((element) => [element.dataset.status, element])
    );

    const directionLabels = new Map([
        [0, 'N'], [45, 'NE'], [90, 'E'], [135, 'SE'],
        [180, 'S'], [225, 'SW'], [270, 'W'], [315, 'NW']
    ]);

    const compassMarks = Array.from({ length: 13 }, () => {
        const mark = document.createElement('div');
        mark.className = 'compass-mark';
        const label = document.createElement('span');
        label.className = 'compass-mark-label';
        mark.appendChild(label);
        compassTrack.appendChild(mark);
        return { mark, label };
    });

    const voiceBarElements = Array.from({ length: 24 }, (_, index) => {
        const bar = document.createElement('span');
        bar.className = 'voice-bar';
        bar.style.setProperty('--bar-angle', `${index * 15}deg`);
        bar.style.setProperty('--bar-delay', `${-(index % 7) * 73}ms`);
        bar.style.setProperty('--bar-level', `${9 + ((index * 7) % 11)}%`);
        voiceBars.appendChild(bar);
        return bar;
    });

    const numberOr = (value, fallback = 0) => {
        const parsed = Number(value);
        return Number.isFinite(parsed) ? parsed : fallback;
    };

    let consumeAudio = null;
    const getConsumeAudio = () => {
        if (consumeAudio) return consumeAudio;
        const AudioCtx = window.AudioContext || window.webkitAudioContext;
        if (!AudioCtx) return null;
        consumeAudio = new AudioCtx();
        return consumeAudio;
    };

    let seatbeltWarnOn = false;
    const setSeatbeltWarn = (playing, fileName) => {
        if (!seatbeltAudio) return;
        const file = (typeof fileName === 'string' && fileName) || 'm.mp3';
        if (playing) {
            const nextSrc = seatbeltAudio.getAttribute('src') || '';
            if (!nextSrc.endsWith(file)) {
                seatbeltAudio.src = file;
            }
            seatbeltAudio.loop = true;
            seatbeltAudio.volume = 1;
            if (!seatbeltWarnOn || seatbeltAudio.paused) {
                const start = seatbeltAudio.play();
                if (start && typeof start.catch === 'function') {
                    start.catch(() => {});
                }
            }
            seatbeltWarnOn = true;
        } else {
            seatbeltWarnOn = false;
            seatbeltAudio.pause();
            try { seatbeltAudio.currentTime = 0; } catch (_) {}
        }
    };

    const playNeedsSound = (kind) => {
        const ctx = getConsumeAudio();
        if (!ctx) return;
        if (ctx.state === 'suspended') ctx.resume().catch(() => {});

        const now = ctx.currentTime;
        const drink = kind === 'drink';
        const bursts = drink ? [0, 0.18] : [0, 0.16, 0.34];

        bursts.forEach((offset, index) => {
            const osc = ctx.createOscillator();
            const filter = ctx.createBiquadFilter();
            const gain = ctx.createGain();
            osc.type = drink ? 'sine' : 'triangle';
            osc.frequency.setValueAtTime(drink ? 180 - (index * 24) : 320 - (index * 40), now + offset);
            filter.type = drink ? 'lowpass' : 'bandpass';
            filter.frequency.setValueAtTime(drink ? 420 : 1100, now + offset);
            gain.gain.setValueAtTime(0.0001, now + offset);
            gain.gain.exponentialRampToValueAtTime(drink ? 0.08 : 0.055, now + offset + 0.03);
            gain.gain.exponentialRampToValueAtTime(0.0001, now + offset + (drink ? 0.22 : 0.14));
            osc.connect(filter);
            filter.connect(gain);
            gain.connect(ctx.destination);
            osc.start(now + offset);
            osc.stop(now + offset + 0.28);
        });
    };

    const normalizeHeading = (value) => ((numberOr(value) % 360) + 360) % 360;
    const setVariable = (name, value) => root.style.setProperty(name, value);
    const moneyFormatter = new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 });
    const suggestionMap = new Map();
    const sentHistory = [];
    const chatConfig = { maxMessages: 100, maxLength: 300, fadeAfter: 9000, timeOffsetHours: -1 };
    let chatIsOpen = false;
    let historyIndex = 0;

    const emojis = [
        '😀', '😂', '😍', '😎', '😭', '😡', '🤔', '🤝',
        '👍', '👎', '👏', '🙏', '💪', '👀', '❤️', '💔',
        '🔥', '✨', '✅', '❌', '⚠️', '🚓', '🚑', '🚗',
        '💰', '🔫', '📍', '📢', '🎉', '💯', '🫡', '🤡'
    ];

    emojis.forEach((emoji) => {
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'emoji-option';
        button.textContent = emoji;
        button.addEventListener('click', () => {
            const start = chatInput.selectionStart ?? chatInput.value.length;
            const end = chatInput.selectionEnd ?? start;
            chatInput.value = `${chatInput.value.slice(0, start)}${emoji}${chatInput.value.slice(end)}`.slice(0, chatConfig.maxLength);
            chatInput.focus();
            chatInput.setSelectionRange(start + emoji.length, start + emoji.length);
            updateChatCounter();
            renderSuggestions();
        });
        emojiPicker.appendChild(button);
    });

    emojiButton.addEventListener('click', () => {
        const open = !emojiPicker.classList.contains('is-open');
        emojiPicker.classList.toggle('is-open', open);
        emojiPicker.setAttribute('aria-hidden', String(!open));
    });

    const applyLayout = (layout = {}, style = {}) => {
        setVariable('--hud-left', `${numberOr(layout.statusLeft)}px`);
        setVariable('--hud-top', `${numberOr(layout.statusTop)}px`);
        setVariable('--hud-width', `${Math.max(150, numberOr(layout.statusWidth, 270))}px`);
        setVariable('--safe-top', `${Math.max(0, numberOr(layout.playerTop, 42))}px`);
        setVariable('--safe-right', `${Math.max(0, numberOr(layout.playerRight, 22))}px`);
        setVariable('--compass-top', `${Math.max(0, numberOr(layout.compassTop, 0))}px`);
        setVariable('--radio-left', `${numberOr(layout.radioLeft != null ? layout.radioLeft : layout.statusLeft)}px`);
        setVariable('--radio-width', `${Math.max(168, numberOr(layout.radioWidth != null ? layout.radioWidth : layout.statusWidth, 250))}px`);
        setVariable('--radio-bottom', `${Math.max(160, numberOr(layout.radioBottom, 320))}px`);

        const variables = {
            statusBackground: '--status-background',
            panelAccent: '--panel-accent',
            compassAccent: '--compass-accent',
            health: '--health-color',
            healthEnd: '--health-color-end',
            water: '--water-color',
            waterEnd: '--water-color-end',
            food: '--food-color',
            foodEnd: '--food-color-end',
            stamina: '--stamina-color',
            staminaEnd: '--stamina-color-end'
        };

        Object.entries(variables).forEach(([key, variable]) => {
            if (typeof style[key] === 'string') {
                setVariable(variable, style[key]);
            }
        });
    };

    const setStatusValue = (name, value) => {
        const element = statusElements.get(name);
        if (!element) {
            return;
        }

        const percentage = Math.max(0, Math.min(100, numberOr(value, 0)));
        element.style.setProperty('--item-value', `${percentage}%`);
        const track = element.querySelector('.status-track');
        if (track) {
            track.setAttribute('aria-valuenow', String(Math.round(percentage)));
        }
    };

    const setAllStatusValues = (values = {}) => {
        Object.entries(values).forEach(([name, value]) => setStatusValue(name, value));
    };

    const formatMoney = (value, symbol) => {
        const amount = Math.max(0, Math.floor(numberOr(value, 0)));
        return `${typeof symbol === 'string' ? symbol : '$'}${moneyFormatter.format(amount)}`;
    };

    const setWeaponImage = (imageName, displayName) => {
        if (typeof imageName !== 'string' || !/^WEAPON_[A-Z0-9_]+$/.test(imageName)) {
            weaponImage.removeAttribute('src');
            weaponImage.classList.add('is-missing');
            return;
        }

        weaponImage.classList.remove('is-missing');
        weaponImage.alt = typeof displayName === 'string' ? displayName : '';
        weaponImage.src = `assets/weapons/${imageName}.png`;
    };

    weaponImage.addEventListener('error', () => {
        weaponImage.classList.add('is-missing');
    });

    const setPlayerInfo = (info = {}) => {
        const armed = info.armed === true;
        const symbol = typeof info.currencySymbol === 'string' ? info.currencySymbol : '$';

        playerName.textContent = `ID ${Math.max(0, Math.floor(numberOr(info.serverId, 0)))}`;
        playerJob.textContent = typeof info.job === 'string' ? info.job : 'Unemployed';
        playerGang.textContent = typeof info.gang === 'string' ? info.gang : 'No Gang';
        playerCash.textContent = formatMoney(info.cash, symbol);
        weaponName.textContent = typeof info.weaponName === 'string' ? info.weaponName : 'Weapon';
        weaponAmmo.textContent = typeof info.ammo === 'string' ? info.ammo : '0';
        weaponRow.classList.toggle('is-visible', armed);

        if (armed) {
            setWeaponImage(info.weaponImage, info.weaponName);
        } else {
            weaponImage.removeAttribute('src');
            weaponImage.classList.add('is-missing');
        }
    };

    const renderCompass = (rawHeading, rawFieldOfView) => {
        const heading = normalizeHeading(rawHeading);
        const fieldOfView = Math.max(60, Math.min(180, numberOr(rawFieldOfView, 120)));
        const step = 15;
        const base = Math.round(heading / step) * step;

        compassHeading.textContent = `${String(Math.round(heading) % 360).padStart(3, '0')}°`;

        compassMarks.forEach(({ mark, label }, index) => {
            const offset = index - 6;
            const unwrappedAngle = base + (offset * step);
            const angle = normalizeHeading(unwrappedAngle);
            let difference = unwrappedAngle - heading;

            while (difference > 180) difference -= 360;
            while (difference < -180) difference += 360;

            const left = 50 + ((difference / fieldOfView) * 100);
            const direction = directionLabels.get(angle);
            const isCardinal = angle % 90 === 0;
            const isIntercardinal = angle % 45 === 0 && !isCardinal;

            mark.style.left = `${left}%`;
            mark.style.opacity = Math.abs(difference) <= fieldOfView / 2 ? '1' : '0';
            mark.classList.toggle('is-cardinal', isCardinal);
            mark.classList.toggle('is-intercardinal', isIntercardinal);
            label.textContent = direction || '';
        });
    };

    const configureVehicle = (config = {}) => {
        vehicleHud.style.setProperty('--vehicle-bottom', `${numberOr(config.centerBottomVh, 1.8)}vh`);
        if (typeof config.accent === 'string') vehicleHud.style.setProperty('--vehicle-accent', config.accent);
        if (typeof config.warning === 'string') vehicleHud.style.setProperty('--vehicle-warning', config.warning);
        if (typeof config.danger === 'string') vehicleHud.style.setProperty('--vehicle-danger', config.danger);
        if (typeof config.gearColor === 'string') vehicleHud.style.setProperty('--vehicle-gear', config.gearColor);
    };

    const layoutVehicleRail = (layout = {}) => {
        vehicleHud.style.setProperty('--rpm-left', `${numberOr(layout.left)}px`);
        vehicleHud.style.setProperty('--rpm-top', `${numberOr(layout.top)}px`);
        vehicleHud.style.setProperty('--rpm-height', `${Math.max(120, numberOr(layout.height, 190))}px`);
    };

    const setVehicleLevel = (container, fill, value) => {
        const percentage = Math.max(0, Math.min(100, numberOr(value, 0)));
        fill.style.width = `${percentage}%`;
        container.classList.toggle('is-low', percentage <= 30 && percentage > 12);
        container.classList.toggle('is-critical', percentage <= 12);
        return percentage;
    };

    const updateVehicle = (data = {}) => {
        const speed = Math.max(0, Math.round(numberOr(data.speed, 0)));
        const rpm = Math.max(0, Math.min(100, numberOr(data.rpm, 0)));
        const fuel = setVehicleLevel(vehicleFuel.closest('.vehicle-stat'), vehicleFuelFill, data.fuel);
        const engine = setVehicleLevel(vehicleEngine.closest('.vehicle-stat'), vehicleEngineFill, data.engine);

        vehicleSpeed.textContent = String(speed).padStart(3, '0');
        vehicleUnit.textContent = typeof data.unit === 'string' ? data.unit : 'KM/H';
        vehicleTrip.textContent = `${numberOr(data.trip, 0).toFixed(1)} KM`;
        vehicleFuel.textContent = String(Math.round(fuel));
        vehicleEngine.textContent = String(Math.round(engine));
        vehicleGear.textContent = typeof data.gear === 'string' ? data.gear : String(data.gear ?? 'N');
        vehicleRpmFill.style.height = `${rpm}%`;
        vehicleRpmFill.classList.toggle('is-redline', rpm >= 88);

        vehicleLeftSignal.classList.toggle('is-active', data.leftIndicator === true || data.hazard === true);
        vehicleRightSignal.classList.toggle('is-active', data.rightIndicator === true || data.hazard === true);
        vehicleSeatbelt.classList.toggle('is-active', data.seatbelt === true);
        vehicleSeatbelt.classList.toggle('is-danger', data.seatbeltAvailable === true && data.seatbelt !== true);
        vehicleSeatbelt.style.opacity = data.seatbeltAvailable === false ? '0.16' : '1';
        if (vehicleIgnition) {
            const running = data.engineRunning === true;
            vehicleIgnition.classList.toggle('is-active', running);
            vehicleIgnition.classList.toggle('is-danger', !running);
        }
        vehicleLights.classList.toggle('is-active', data.lights === true);
        vehicleLock.classList.toggle('is-active', data.locked === true);
    };

    const setVehicleVisible = (visible) => {
        vehicleHud.classList.toggle('is-visible', visible === true);
        if (visible !== true) {
            setSeatbeltWarn(false);
        }
    };

    let radioCurrent = null;
    let radioCurrentLabel = '';

    const stationFreq = (index) => `${(88.1 + (index * 1.8)).toFixed(1)} FM`;

    const setRadioMeta = (label) => {
        const live = Boolean(label);
        if (radioNow) radioNow.textContent = label || 'Standby';
        if (radioSub) radioSub.textContent = live ? 'On air' : 'Choose a station';
        if (radioPanel) radioPanel.classList.toggle('is-live', live);
    };

    const setCabinSlider = (volume) => {
        if (typeof volume !== 'number') return;
        const percent = Math.round(Math.max(0, Math.min(1, volume)) * 100);
        if (radioVolume) {
            radioVolume.value = String(percent);
            radioVolume.style.setProperty('--vol', `${percent}%`);
        }
        if (radioPanel) radioPanel.style.setProperty('--vol', `${percent}%`);
        if (radioVolNum) radioVolNum.textContent = String(percent);
    };

    const renderRadioStations = (stations = [], current = null) => {
        if (!radioList) return;
        radioList.replaceChildren();
        radioCurrent = current;

        stations.forEach((station, index) => {
            const button = document.createElement('button');
            button.type = 'button';
            button.className = 'radio-station';
            button.dataset.stationId = station.id;
            if (station.id === current) button.classList.add('is-live');
            if (!station.ready) button.classList.add('is-disabled');

            const num = document.createElement('span');
            num.className = 'radio-index';
            num.textContent = String(index + 1).padStart(2, '0');

            const copy = document.createElement('span');
            copy.className = 'radio-copy';

            const label = document.createElement('span');
            label.className = 'radio-label';
            label.textContent = station.label || station.id;

            const freq = document.createElement('span');
            freq.className = 'radio-freq';
            freq.textContent = stationReadyLabel(station, index);

            copy.append(label, freq);

            const state = document.createElement('span');
            state.className = 'radio-state';
            if (!station.ready) state.textContent = 'EMPTY';
            else if (station.id === current) state.textContent = 'LIVE';
            else state.textContent = 'SET';

            button.append(num, copy, state);
            button.addEventListener('click', () => {
                if (!station.ready) return;
                postNui('vnRadioSelect', { id: station.id });
            });
            radioList.appendChild(button);
        });
    };

    const stationReadyLabel = (station, index) => {
        if (!station.ready) return 'No tracks';
        return stationFreq(index);
    };

    const playRadio = (data = {}) => {
        if (!radioAudio) return;
        const url = typeof data.url === 'string' ? data.url : '';
        radioCurrent = data.id || null;
        radioCurrentLabel = data.label || radioCurrent || '';
        setRadioMeta(radioCurrent ? radioCurrentLabel : '');
        [...(radioList ? radioList.children : [])].forEach((node) => {
            const live = node.dataset.stationId === radioCurrent;
            node.classList.toggle('is-live', live);
            const state = node.querySelector('.radio-state');
            if (state && !node.classList.contains('is-disabled')) {
                state.textContent = live ? 'LIVE' : 'SET';
            }
        });

        if (!url) {
            radioAudio.pause();
            radioAudio.removeAttribute('src');
            radioAudio.load();
            return;
        }

        const output = typeof data.volume === 'number' ? data.volume : radioAudio.volume;
        radioAudio.volume = Math.max(0, Math.min(1, output));
        if (data.syncSlider === true) {
            setCabinSlider(typeof data.cabinVolume === 'number' ? data.cabinVolume : output);
        }
        if (radioAudio.getAttribute('src') !== url) {
            radioAudio.src = url;
        }
        radioAudio.play().catch(() => {});
    };

    if (radioAudio) {
        radioAudio.addEventListener('ended', () => postNui('vnRadioEnded'));
        radioAudio.addEventListener('error', () => postNui('vnRadioEnded'));
    }

    if (radioClose) {
        radioClose.addEventListener('click', () => postNui('vnRadioClose'));
    }
    if (radioVolume) {
        radioVolume.addEventListener('input', () => {
            const volume = Number(radioVolume.value) / 100;
            const percent = Math.round(volume * 100);
            if (radioVolNum) radioVolNum.textContent = String(percent);
            if (radioPanel) radioPanel.style.setProperty('--vol', `${percent}%`);
            radioVolume.style.setProperty('--vol', `${percent}%`);
            if (radioAudio && radioPanel && radioPanel.classList.contains('is-open')) {
                radioAudio.volume = volume;
            }
            postNui('vnRadioVolume', { volume });
        });
    }
    window.addEventListener('keydown', (event) => {
        if (!radioPanel || !radioPanel.classList.contains('is-open')) return;
        if (event.key === 'Escape' || event.key === 'q' || event.key === 'Q') {
            event.preventDefault();
            postNui('vnRadioClose');
        }
    });

    const configureVoice = (config = {}) => {
        const sizeVh = Math.max(5, numberOr(config.sizeVh, 7.8));
        voiceWidget.style.setProperty('--voice-size', `${sizeVh}vh`);
        voiceWidget.style.setProperty('--voice-radius', `${-(sizeVh * 0.49)}vh`);
        voiceWidget.style.setProperty('--voice-right', `${numberOr(config.offsetRightVw, 1.35)}vw`);
        voiceWidget.style.setProperty('--voice-bottom', `${numberOr(config.offsetBottomVh, 1.8)}vh`);
        if (typeof config.accent === 'string') voiceWidget.style.setProperty('--voice-accent', config.accent);
        if (typeof config.radioColor === 'string') voiceWidget.style.setProperty('--voice-radio', config.radioColor);
    };

    const updateVoice = (data = {}) => {
        const talking = data.talking === true;
        const radio = data.radio === true;
        voiceWidget.classList.toggle('is-talking', talking);
        voiceWidget.classList.toggle('is-radio', radio);
        voiceWidget.classList.toggle('is-hidden', data.visible === false);
    };

    const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'vn-hud';

    const postNui = async (callback, payload = {}) => {
        try {
            await fetch(`https://${resourceName}/${callback}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(payload)
            });
        } catch (_) {}
    };

    const stripGameFormatting = (value) => String(value ?? '').replace(/\^[0-9]/g, '').trim();

    const messageColor = (color) => {
        if (Array.isArray(color) && color.length >= 3) {
            const channels = color.slice(0, 3).map((value) => Math.max(0, Math.min(255, numberOr(value))));
            return `rgb(${channels.join(',')})`;
        }
        if (typeof color === 'string' && /^(#[0-9a-f]{3,8}|rgb\()/i.test(color)) {
            return color;
        }
        return 'var(--chat-accent)';
    };

    const scrollChatToBottom = () => {
        chatMessages.scrollTop = chatMessages.scrollHeight;
    };

    const addChatMessage = (message = {}) => {
        const args = Array.isArray(message.args) ? message.args.map(stripGameFormatting) : [];
        const author = args.length > 1 ? args.shift() : stripGameFormatting(message.author || '');
        const text = stripGameFormatting(args.length ? args.join(' ') : (message.text || message.message || ''));

        if (!text) {
            return;
        }

        const item = document.createElement('div');
        item.className = 'chat-message';
        item.dataset.createdAt = String(Date.now());
        item.style.setProperty('--message-color', messageColor(message.color));

        if (typeof message.tag === 'string' && message.tag) {
            const tagElement = document.createElement('span');
            tagElement.className = 'chat-tag';
            tagElement.textContent = `[${stripGameFormatting(message.tag)}]`;
            item.appendChild(tagElement);
        }

        if (author) {
            const authorElement = document.createElement('span');
            authorElement.className = 'chat-author';
            authorElement.textContent = author;
            item.appendChild(authorElement);
        }

        const textElement = document.createElement('span');
        textElement.className = 'chat-text';
        textElement.textContent = text;
        item.appendChild(textElement);

        const time = new Date(Date.now() + (chatConfig.timeOffsetHours * 60 * 60 * 1000));
        const timeElement = document.createElement('span');
        timeElement.className = 'chat-time';
        timeElement.textContent = `${String(time.getHours()).padStart(2, '0')}:${String(time.getMinutes()).padStart(2, '0')}`;
        item.appendChild(timeElement);

        const wasNearBottom = (chatMessages.scrollHeight - chatMessages.scrollTop - chatMessages.clientHeight) < 45;
        chatMessages.appendChild(item);
        while (chatMessages.children.length > chatConfig.maxMessages) {
            chatMessages.firstElementChild?.remove();
        }
        if (!chatIsOpen || wasNearBottom) scrollChatToBottom();
    };

    const renderSuggestions = () => {
        const query = chatInput.value.trim().toLowerCase();
        chatSuggestions.replaceChildren();

        if (!chatIsOpen || !query.startsWith('/')) {
            chatSuggestions.classList.remove('has-items');
            return;
        }

        const matches = [...suggestionMap.values()]
            .filter((suggestion) => suggestion.name.toLowerCase().startsWith(query))
            .slice(0, 6);

        matches.forEach((suggestion) => {
            const row = document.createElement('div');
            row.className = 'chat-suggestion';

            const name = document.createElement('span');
            name.className = 'chat-suggestion-name';
            name.textContent = suggestion.name;

            const help = document.createElement('span');
            help.className = 'chat-suggestion-help';
            help.textContent = suggestion.help || '';

            row.append(name, help);
            chatSuggestions.appendChild(row);
        });

        chatSuggestions.classList.toggle('has-items', matches.length > 0);
    };

    const updateChatCounter = () => {
        chatCounter.textContent = `${chatInput.value.length}/${chatConfig.maxLength}`;
    };

    const openChat = () => {
        chatIsOpen = true;
        chatShell.classList.add('is-open');
        [...chatMessages.children].forEach((message) => message.classList.remove('is-faded'));
        historyIndex = sentHistory.length;
        updateChatCounter();
        renderSuggestions();
        const focusInput = () => {
            chatInput.focus();
            scrollChatToBottom();
        };
        if (typeof window.requestAnimationFrame === 'function') {
            window.requestAnimationFrame(focusInput);
        } else {
            setTimeout(focusInput, 0);
        }
    };

    const closeChat = () => {
        chatIsOpen = false;
        chatShell.classList.remove('is-open');
        chatInput.blur();
        chatInput.value = '';
        emojiPicker.classList.remove('is-open');
        emojiPicker.setAttribute('aria-hidden', 'true');
        updateChatCounter();
        renderSuggestions();
    };

    const submitChat = () => {
        const message = chatInput.value.trim();
        if (message) {
            if (sentHistory[sentHistory.length - 1] !== message) {
                sentHistory.push(message);
                if (sentHistory.length > 30) sentHistory.shift();
            }
            postNui('vnChatSubmit', { message });
        } else {
            postNui('vnChatClose');
        }
        closeChat();
    };

    chatInput.addEventListener('input', () => {
        if (chatInput.value.length > chatConfig.maxLength) {
            chatInput.value = chatInput.value.slice(0, chatConfig.maxLength);
        }
        updateChatCounter();
        renderSuggestions();
    });

    chatInput.addEventListener('keydown', (event) => {
        if (event.key === 'Enter') {
            event.preventDefault();
            submitChat();
        } else if (event.key === 'Escape') {
            event.preventDefault();
            postNui('vnChatClose');
            closeChat();
        } else if (event.key === 'ArrowUp' && sentHistory.length) {
            event.preventDefault();
            historyIndex = Math.max(0, historyIndex - 1);
            chatInput.value = sentHistory[historyIndex] || '';
            updateChatCounter();
            renderSuggestions();
        } else if (event.key === 'ArrowDown' && sentHistory.length) {
            event.preventDefault();
            historyIndex = Math.min(sentHistory.length, historyIndex + 1);
            chatInput.value = sentHistory[historyIndex] || '';
            updateChatCounter();
            renderSuggestions();
        } else if (event.key === 'PageUp') {
            event.preventDefault();
            chatMessages.scrollBy({ top: -(chatMessages.clientHeight * 0.82), behavior: 'smooth' });
        } else if (event.key === 'PageDown') {
            event.preventDefault();
            chatMessages.scrollBy({ top: chatMessages.clientHeight * 0.82, behavior: 'smooth' });
        } else if (event.key === 'Tab') {
            const first = [...suggestionMap.values()].find((suggestion) =>
                suggestion.name.toLowerCase().startsWith(chatInput.value.trim().toLowerCase())
            );
            if (first) {
                event.preventDefault();
                chatInput.value = `${first.name} `;
                updateChatCounter();
                renderSuggestions();
            }
        }
    });

    setInterval(() => {
        if (chatIsOpen) return;
        const now = Date.now();
        [...chatMessages.children].forEach((message) => {
            if (now - numberOr(message.dataset.createdAt) >= chatConfig.fadeAfter) {
                message.classList.add('is-faded');
            }
        });
    }, 500);

    window.addEventListener('message', ({ data }) => {
        if (!data || typeof data.action !== 'string') {
            return;
        }

        switch (data.action) {
            case 'hud:layout':
                applyLayout(data.layout, data.style);
                break;
            case 'status:values':
                setAllStatusValues(data.values);
                break;
            case 'status:visibility':
                statusHud.classList.toggle('is-visible', data.visible === true);
                break;
            case 'player:info':
                setPlayerInfo(data.info);
                break;
            case 'upper:visibility':
                playerPanel.classList.toggle('is-visible', data.player === true);
                compass.classList.toggle('is-visible', data.compass === true);
                break;
            case 'compass:heading':
                renderCompass(data.heading, data.fieldOfView);
                break;
            case 'vehicle:configure':
                configureVehicle(data.config);
                break;
            case 'vehicle:layout':
                layoutVehicleRail(data.layout);
                break;
            case 'vehicle:update':
                updateVehicle(data);
                break;
            case 'vehicle:visibility':
                setVehicleVisible(data.visible);
                break;
            case 'voice:configure':
                configureVoice(data.config);
                break;
            case 'voice:update':
                updateVoice(data);
                break;
            case 'chat:configure':
                if (data.config) {
                    chatConfig.maxMessages = Math.max(10, numberOr(data.config.maxMessages, 100));
                    chatConfig.maxLength = Math.max(32, numberOr(data.config.maxLength, 300));
                    chatConfig.fadeAfter = Math.max(1000, numberOr(data.config.fadeAfter, 9000));
                    chatConfig.timeOffsetHours = numberOr(data.config.timeOffsetHours, -1);
                    chatInput.maxLength = chatConfig.maxLength;
                    if (typeof data.config.accent === 'string') {
                        chatShell.style.setProperty('--chat-accent', data.config.accent);
                    }
                    if (data.config.position) {
                        const position = data.config.position;
                        chatShell.style.setProperty('--chat-top', `${numberOr(position.TopVh, 2.2)}vh`);
                        chatShell.style.setProperty('--chat-left', `${numberOr(position.LeftVw, 1.4)}vw`);
                        chatShell.style.setProperty('--chat-width', `${numberOr(position.WidthVw, 26)}vw`);
                        chatShell.style.setProperty('--chat-height', `${numberOr(position.HeightVh, 28)}vh`);
                    }
                    updateChatCounter();
                }
                break;
            case 'chat:open':
                openChat();
                break;
            case 'chat:close':
                closeChat();
                break;
            case 'chat:addMessage':
                addChatMessage(data.message);
                break;
            case 'chat:addSuggestion':
                if (data.suggestion && typeof data.suggestion.name === 'string') {
                    suggestionMap.set(data.suggestion.name, data.suggestion);
                    renderSuggestions();
                }
                break;
            case 'chat:removeSuggestion':
                suggestionMap.delete(data.name);
                renderSuggestions();
                break;
            case 'chat:clear':
                chatMessages.replaceChildren();
                break;
            case 'radio:open':
                if (radioPanel) {
                    radioPanel.classList.add('is-open');
                    radioPanel.setAttribute('aria-hidden', 'false');
                }
                renderRadioStations(data.stations || [], data.current || null);
                setCabinSlider(typeof data.volume === 'number' ? data.volume : 0.55);
                if (data.current) {
                    const live = (data.stations || []).find((station) => station.id === data.current);
                    setRadioMeta((live && live.label) || radioCurrentLabel || data.current);
                } else {
                    setRadioMeta('');
                }
                break;
            case 'radio:visibility':
                if (radioPanel) {
                    radioPanel.classList.toggle('is-open', data.visible === true);
                    radioPanel.setAttribute('aria-hidden', String(data.visible !== true));
                }
                break;
            case 'radio:configure':
                renderRadioStations(data.stations || [], radioCurrent);
                if (typeof data.volume === 'number') {
                    setCabinSlider(data.volume);
                }
                break;
            case 'radio:play':
                playRadio(data);
                break;
            case 'needs:sound':
                playNeedsSound(data.kind);
                break;
            case 'seatbelt:chime':
            case 'seatbelt:warn':
                setSeatbeltWarn(data.playing !== false, data.file);
                break;
            default:
                break;
        }
    });

    setTimeout(() => {
        postNui('vnHudReady');
        postNui('vnChatReady');
        postNui('vnVoiceReady');
        postNui('vnVehicleReady');
        postNui('vnRadioReady');
    }, 150);
})();
