const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-hud';
const nuiPost = (name, data = {}) => fetch(`https://${RESOURCE}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
}).catch(() => {});

const safeStorage = {
    get(key) {
        try { return JSON.parse(localStorage.getItem(key)) || {}; } catch (e) { return {}; }
    },
    set(key, value) {
        try { localStorage.setItem(key, JSON.stringify(value)); } catch (e) { /* storage unavailable */ }
    }
};

// icons the player hid via /hudpreset (shared between the HUD and preset apps)
const hudHidden = Vue.reactive({});
function setHidden(list) {
    Object.keys(hudHidden).forEach(k => delete hudHidden[k]);
    Object.entries(list || {}).forEach(([k, v]) => { if (v) hudHidden[k] = true; });
}

// per-player display settings (from the saved preset, shared by the HUD + settings apps)
const hudDisplay = Vue.reactive({ showPct: false, alwaysShow: false, voiceAlways: true, money: true, opacity: 100, scale: 100, mapFoot: 'map', mapMount: 'map', colors: {} });
const RING_DEFAULTS = { good: '#6fbf73', warn: '#d9a441', bad: '#e0554f' };
function applyDisplay(d) {
    Object.assign(hudDisplay, d || {});
    if (!hudDisplay.colors || Array.isArray(hudDisplay.colors)) hudDisplay.colors = {}; // lua sends [] for an empty table
    const ui = document.getElementById('ui-container');
    const money = document.getElementById('money-container');
    const op = Math.max(0.1, Math.min(1, (Number(hudDisplay.opacity) || 100) / 100));
    if (ui) {
        ui.style.opacity = op;
        ui.style.setProperty('--hud-scale', (Number(hudDisplay.scale) || 100) / 100);
        Object.keys(RING_DEFAULTS).forEach(k => {
            const v = hudDisplay.colors['ring.' + k];
            if (v) ui.style.setProperty('--ring-' + k, v); else ui.style.removeProperty('--ring-' + k);
        });
    }
    if (money) {
        money.style.opacity = op;
        money.classList.toggle('money-off', !hudDisplay.money);
    }
}

// ============ MONEY HUD ============
// Configure your currency / locale here
const moneyFormatter = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 0,
    maximumFractionDigits: 2
});
const MONEY_FLAGS = { cash: 'showCash', bloodmoney: 'showBloodmoney', bank: 'showBank' };

Vue.createApp({
    data() {
        return {
            cash: 0, bloodmoney: 0, bank: 0, amount: 0,
            minus: false,
            showCash: false, showBloodmoney: false, showBank: false, showUpdate: false,
            editMode: false,
            locales: {}
        };
    },
    created() { this.timers = {}; },
    mounted() {
        this.listener = ({ data }) => {
            switch (data.action) {
                case 'update': this.update(data); break;
                case 'show': this.showAccounts(data); break;
                case 'toggleEditMode': this.editMode = data.enabled; break;
                case 'setLocales': this.locales = data.locales; break;
            }
        };
        window.addEventListener('message', this.listener);
    },
    unmounted() { window.removeEventListener('message', this.listener); },
    methods: {
        formatMoney(value) { return moneyFormatter.format(Number(value) || 0); },
        flash(type, ms, updateMs) {
            const flag = MONEY_FLAGS[type];
            if (!flag) return;
            this[flag] = true;
            clearTimeout(this.timers[flag]);
            this.timers[flag] = setTimeout(() => { this[flag] = false; }, ms);
            if (updateMs) {
                clearTimeout(this.timers.update);
                this.timers.update = setTimeout(() => { this.showUpdate = false; }, updateMs);
            }
        },
        update(data) {
            this.cash = data.cash;
            this.bloodmoney = data.bloodmoney;
            this.bank = data.bank;
            this.amount = data.amount;
            this.minus = !!data.minus;
            this.showUpdate = true;
            this.flash(data.type, 2000, 1000);
        },
        showAccounts(data) {
            if (!MONEY_FLAGS[data.type]) return;
            this[data.type] = data[data.type];
            this.flash(data.type, 3500);
        }
    }
}).mount('#money-container');

// ============ PLAYER HUD ============
const LOW = 30;
const DEFAULT_COLORS = { normal: '#FFFFFF', low: '#e0554f', active: '#e0554f' };

Vue.createApp({
    data() {
        return {
            show: false,
            editMode: false,
            voiceEnabled: false,
            display: hudDisplay,
            iconColors: {},
            locales: {},
            health: 0, stamina: 0, hunger: 0, thirst: 0, cleanliness: 0, stress: 0,
            temp: '0°C',
            onHorse: false, horsehealth: 0, horsestamina: 0, horseclean: 0, horsehunger: null, horsethirst: null,
            talking: false, youhavemail: false, outlawstatus: 0,
            deadeye: 0, horsebond: 0, tempStatus: false,
            deadeyeEnabled: false, bondEnabled: false, horseNeedsEnabled: false,
            hidden: hudHidden
        };
    },
    mounted() {
        this.listener = ({ data }) => {
            switch (data.action) {
                case 'hudtick': this.hudTick(data); break;
                case 'toggleEditMode': this.editMode = data.enabled; break;
                case 'setLocales': this.locales = data.locales; break;
                case 'setConfig':
                    this.iconColors = data.iconColors || {};
                    this.voiceEnabled = data.voiceEnabled === true;
                    this.deadeyeEnabled = data.deadeyeEnabled === true;
                    this.bondEnabled = data.bondEnabled === true;
                    this.horseNeedsEnabled = data.horseNeedsEnabled === true;
                    break;
            }
        };
        window.addEventListener('message', this.listener);
    },
    unmounted() { window.removeEventListener('message', this.listener); },
    computed: {
        showPct() { return this.display.showPct; },
        // visibility: elements hide when "full"/irrelevant, edit mode forces everything on
        vis() {
            const e = this.editMode, h = this.hidden;
            const f = e || this.display.alwaysShow; // "always show" keeps full icons on screen
            const v = {
                health: f || this.health < 100,
                stamina: f || this.stamina < 100,
                deadeye: this.deadeyeEnabled && (f || this.deadeye < 100),
                hunger: f || this.hunger < 100,
                thirst: f || this.thirst < 100,
                cleanliness: f || this.cleanliness < 100,
                stress: f || this.stress > 0,
                temp: true,
                horse: e || this.onHorse,
                voice: this.voiceEnabled && (e || this.display.voiceAlways || this.talking),
                mail: e || this.youhavemail,
                outlaw: e || this.isOutlaw
            };
            // player-hidden icons stay hidden outside edit mode
            if (!e) Object.keys(h).forEach(k => { if (k in v) v[k] = false; });
            v.horsebond = this.bondEnabled && v.horse && (e || !h.horsebond);
            // only shown for the player's own rsg-stables horse (null = no data)
            v.horsehunger = this.horseNeedsEnabled && v.horse && (e || (this.horsehunger !== null && !h.horsehunger));
            v.horsethirst = this.horseNeedsEnabled && v.horse && (e || (this.horsethirst !== null && !h.horsethirst));
            return v;
        },
        isOutlaw() { return this.outlawstatus >= 100; },
        tempValue() { return parseFloat(this.temp) || 0; },
        isFahrenheit() { return String(this.temp).includes('F'); },
        tempCelsius() { return this.isFahrenheit ? (this.tempValue - 32) * 5 / 9 : this.tempValue; },
        tempIcon() {
            if (this.tempStatus === 'cold') return 'fa-snowflake';
            if (this.tempStatus === 'hot') return 'fa-sun';
            return 'fa-temperature-half';
        },
        tempClass() {
            if (this.tempStatus) return 'stat-bad';
            const c = this.tempCelsius;
            if (c <= 0 || c >= 40) return 'stat-bad';
            if (c <= 10 || c >= 30) return 'stat-warn';
            return 'stat-good';
        },
        tempPct() { return this.clampPct((this.tempCelsius + 10) / 50 * 100); },
        tempColor() {
            const c = this.iconColors.temp || {}, o = this.display.colors || {};
            return this.tempCelsius <= 10 ? (o['temp.alert'] || c.cold || '#d9a441') : (o['temp.normal'] || c.normal || '#f2f2f2');
        }
    },
    methods: {
        clampPct(v) { return Math.max(0, Math.min(100, Math.round(parseFloat(v) || 0))); },
        barClass(v) {
            const n = parseFloat(v) || 0;
            return n <= LOW ? 'stat-bad' : n <= 70 ? 'stat-warn' : 'stat-good';
        },
        barClassInvert(v) {
            const n = parseFloat(v) || 0;
            return n >= 70 ? 'stat-bad' : n >= 40 ? 'stat-warn' : 'stat-good';
        },
        // icon colour from Config.IconColors; `alert` picks the low/active variant
        iconColor(key, alert) {
            const o = (this.display.colors || {})[key + (alert ? '.alert' : '.normal')];
            if (o) return o; // player's own colour from the settings window
            const c = this.iconColors[key] || {};
            return alert ? (c.low || c.active || c.hasmail || DEFAULT_COLORS.low) : (c.normal || DEFAULT_COLORS.normal);
        },
        hudTick(data) {
            this.show = data.show;
            if (!data.show) return; // hidden ticks carry no stats
            this.health = data.health;
            this.stamina = parseInt(data.stamina) || 0;
            this.hunger = data.hunger;
            this.thirst = data.thirst;
            this.cleanliness = data.cleanliness;
            this.stress = data.stress;
            this.temp = data.temp;
            this.talking = data.talking;
            this.youhavemail = data.youhavemail;
            this.outlawstatus = Number(data.outlawstatus) || 0;
            this.deadeye = Number(data.deadeye) || 0;
            this.tempStatus = data.tempStatus || false;
            this.onHorse = data.onHorse;
            if (data.onHorse) {
                this.horsehealth = data.horsehealth;
                this.horsestamina = data.horsestamina;
                this.horseclean = data.horseclean;
                this.horsebond = Number(data.horsebond) || 0;
                this.horsehunger = typeof data.horsehunger === 'number' ? data.horsehunger : null;
                this.horsethirst = typeof data.horsethirst === 'number' ? data.horsethirst : null;
            }
        }
    }
}).mount('#ui-container');

// ============ HUD DRAG / RESIZE (edit mode) ============
const STYLE_PROPS = ['position', 'left', 'top', 'right', 'bottom', 'width', 'height', 'transform', 'transformOrigin', 'display', 'flex', 'alignSelf'];
class HUDDragSystem {
    constructor() {
        this.mode = null;          // 'drag' | 'resize' | null
        this.el = null;
        this.editMode = false;
        this.dragOffset = { x: 0, y: 0 };
        this.positions = safeStorage.get('hudPositions');
        this.sizes = safeStorage.get('hudSizes');

        this.applySaved();

        document.addEventListener('mousedown', (e) => this.onMouseDown(e));
        document.addEventListener('mousemove', (e) => this.onMouseMove(e));
        const stop = () => this.stop();
        document.addEventListener('mouseup', stop);
        document.addEventListener('mouseleave', stop);
        window.addEventListener('blur', stop);
        window.addEventListener('resize', () => this.applySaved());
        document.addEventListener('keydown', (e) => this.onKeyDown(e));

        window.addEventListener('message', ({ data }) => {
            if (data.action === 'toggleEditMode') this.toggleEditMode(data.enabled);
            else if (data.action === 'resetPositions') this.resetToDefaults();
        });
    }

    find(name) { return document.querySelector(`[data-element="${name}"]`); }

    // money container is absolutely positioned, bars/badges are fixed
    pin(el, x, y) {
        el.style.position = el.id === 'money-container' ? 'absolute' : 'fixed';
        el.style.left = x + 'px';
        el.style.top = y + 'px';
        el.style.right = 'auto';
        el.style.bottom = 'auto';
    }

    applySaved() {
        for (const [name, size] of Object.entries(this.sizes)) {
            const el = this.find(name);
            if (el && size) this.applySize(el, size);
        }
        for (const [name, pos] of Object.entries(this.positions)) {
            const el = this.find(name);
            if (!el || !pos) continue;
            // keep saved elements on-screen if the resolution changed
            const w = el.offsetWidth || 40, h = el.offsetHeight || 40;
            const x = Math.max(0, Math.min(pos.x, window.innerWidth - w));
            const y = Math.max(0, Math.min(pos.y, window.innerHeight - h));
            this.pin(el, x, y);
        }
    }

    toggleEditMode(enabled) {
        this.editMode = enabled;
        document.querySelectorAll('.draggable-element').forEach(el => {
            el.classList.toggle('edit-mode', enabled);
            if (!enabled) el.classList.remove('dragging', 'resizing');
        });
        if (!enabled) this.stop();
    }

    onMouseDown(e) {
        if (!this.editMode || e.button !== 0) return;
        if (e.target.classList.contains('resize-handle')) {
            e.preventDefault();
            this.startResize(e.target.parentElement, e);
            return;
        }
        const target = e.target.closest('.stat-row, .mini-badge, #money-container');
        if (target) {
            e.preventDefault();
            this.startDrag(target, e);
        }
    }

    startDrag(el, e) {
        const rect = el.getBoundingClientRect();
        this.mode = 'drag';
        this.el = el;
        this.dragOffset = { x: e.clientX - rect.left, y: e.clientY - rect.top };
        el.classList.add('dragging');
        this.pin(el, rect.left, rect.top);
    }

    startResize(el, e) {
        this.mode = 'resize';
        this.el = el;
        this.startMouse = { x: e.clientX, y: e.clientY };
        this.startWidth = el.getBoundingClientRect().width;
        el.classList.add('resizing');
        document.body.style.cursor = 'nw-resize';
    }

    onMouseMove(e) {
        if (!this.el) return;
        e.preventDefault();
        if (this.mode === 'drag') {
            const rect = this.el.getBoundingClientRect();
            const grid = 10;
            const maxX = window.innerWidth - rect.width;
            const maxY = window.innerHeight - rect.height;
            const x = Math.max(0, Math.min(Math.round((e.clientX - this.dragOffset.x) / grid) * grid, maxX));
            const y = Math.max(0, Math.min(Math.round((e.clientY - this.dragOffset.y) / grid) * grid, maxY));
            this.el.style.left = x + 'px';
            this.el.style.top = y + 'px';
        } else if (this.mode === 'resize') {
            const delta = Math.max(e.clientX - this.startMouse.x, e.clientY - this.startMouse.y);
            const max = Math.min(window.innerWidth, window.innerHeight) * 0.3;
            this.applySize(this.el, Math.min(Math.max(30, this.startWidth + delta), max));
        }
    }

    onKeyDown(e) {
        if (e.key !== 'Escape') return;
        if (this.mode) this.stop();
        else if (this.editMode) nuiPost('disableEditMode');
    }

    applySize(el, size) {
        el.style.width = size + 'px';
        if (el.classList.contains('stat-circle') || el.classList.contains('voice-inline')) {
            el.style.height = size + 'px';
            el.style.flex = `0 0 ${size}px`; // CSS flex-basis was pinning the width at 72px
            el.style.alignSelf = 'center';
            el.style.setProperty('--circle-size', size + 'px'); // lets icon-only mode scale the glyph
            el.style.transform = '';
            return;
        }
        if (el.classList.contains('stat-row')) {
            el.style.transform = '';
            return;
        }
        // badges / money: uniform scale from a ~60px base
        el.style.height = size + 'px';
        el.style.transform = `scale(${size / 60})`;
        el.style.transformOrigin = 'center center';
        if (!el.classList.contains('mini-badge')) el.style.display = 'inline-block';
    }

    stop() {
        const el = this.el;
        if (el) {
            const name = el.getAttribute('data-element');
            if (this.mode === 'drag' && name) {
                this.positions[name] = { x: parseInt(el.style.left) || 0, y: parseInt(el.style.top) || 0 };
                safeStorage.set('hudPositions', this.positions);
            } else if (this.mode === 'resize' && name) {
                this.sizes[name] = el.getBoundingClientRect().width;
                safeStorage.set('hudSizes', this.sizes);
            }
            el.classList.remove('dragging', 'resizing');
        }
        this.mode = null;
        this.el = null;
        document.body.style.cursor = '';
        document.body.style.userSelect = '';
    }

    // drop custom drag/resize for stat icons + badges (money keeps its spot)
    clearStatLayout() {
        this.stop();
        document.querySelectorAll('#ui-container .draggable-element').forEach(el => {
            STYLE_PROPS.forEach(p => { el.style[p] = ''; });
            el.classList.remove('dragging', 'resizing');
            el.style.removeProperty('--circle-size');
            const name = el.getAttribute('data-element');
            if (name) { delete this.positions[name]; delete this.sizes[name]; }
        });
        safeStorage.set('hudPositions', this.positions);
        safeStorage.set('hudSizes', this.sizes);
    }

    resetToDefaults() {
        this.clearStatLayout();
        const money = this.find('money');
        if (money) STYLE_PROPS.forEach(p => { money.style[p] = ''; });
        this.positions = {};
        this.sizes = {};
        safeStorage.set('hudPositions', this.positions);
        safeStorage.set('hudSizes', this.sizes);
    }
}

const hudDrag = new HUDDragSystem();

// live-apply preset classes to the stat HUD
function applyPresetClasses(p) {
    const ui = document.getElementById('ui-container');
    if (!ui || !p) return;
    [...ui.classList].filter(c => /^(hud-size|hud-pos|hud-orient)-/.test(c)).forEach(c => ui.classList.remove(c));
    ui.classList.add(`hud-size-${p.size || 'medium'}`, `hud-pos-${p.align || 'bottom-center'}`, `hud-orient-${p.orientation || 'horizontal'}`);
    ui.style.setProperty('--hud-offset-x', (Number(p.offsetX) || 0) + 'px');
    ui.style.setProperty('--hud-offset-y', (Number(p.offsetY) || 0) + 'px');
}

// ============ HUD SETTINGS WINDOW (NUI, movable) ============
const SETTINGS_POS_KEY = 'rsghud_settings_pos';
const SETTINGS_TABS = [
    { key: 'layout', icon: 'fa-table-cells-large' },
    { key: 'icons', icon: 'fa-eye' },
    { key: 'display', icon: 'fa-sliders' },
    { key: 'map', icon: 'fa-compass', needs: 'allowMap' },
    { key: 'colors', icon: 'fa-palette', needs: 'allowColors' }
];
const COLOR_ICONS = [
    { key: 'health', label: 'health_label', icon: 'fa-heart-pulse' }, { key: 'stamina', label: 'stamina_label', icon: 'fa-bolt' },
    { key: 'deadeye', label: 'deadeye_label', icon: 'fa-eye', needs: 'deadeyeEnabled' }, { key: 'hunger', label: 'hunger_label', icon: 'fa-drumstick-bite' },
    { key: 'thirst', label: 'thirst_label', icon: 'fa-droplet' }, { key: 'cleanliness', label: 'clean_label', icon: 'fa-pump-soap' },
    { key: 'stress', label: 'stress_label', icon: 'fa-brain' }, { key: 'temp', label: 'temp_label', icon: 'fa-temperature-half' },
    { key: 'voice', label: 'voice_label', icon: 'fa-microphone', needs: 'voiceEnabled' }, { key: 'mail', label: 'mail_label', icon: 'fa-envelope' },
    { key: 'outlaw', label: 'outlaw_label', icon: 'fa-mask' }, { key: 'horse_health', label: 'horse_health_label', icon: 'fa-heart' },
    { key: 'horse_stamina', label: 'horse_stamina_label', icon: 'fa-bolt' }, { key: 'horse_clean', label: 'horse_clean_label', icon: 'fa-pump-soap' },
    { key: 'horse_bond', label: 'horse_bond_label', icon: 'fa-handshake-angle', needs: 'bondEnabled' },
    { key: 'horse_hunger', label: 'horse_hunger_label', icon: 'fa-wheat-awn', needs: 'horseNeedsEnabled' },
    { key: 'horse_thirst', label: 'horse_thirst_label', icon: 'fa-droplet', needs: 'horseNeedsEnabled' }
];
const COLOR_SWATCHES = ['#ffffff', '#f2f2f2', '#9a9a9a', '#5a5a5a', '#e0554f', '#c0392b', '#d9a441', '#f1c40f', '#6fbf73', '#5a7d4f', '#4fa3e0', '#2e6da4', '#9b6fe0', '#e07ab8', '#8b5a2b', '#000000'];
const HEX_RE = /^#[0-9a-f]{6}$/i;
function hexToHsv(hex) {
    const n = parseInt(hex.slice(1), 16), r = (n >> 16 & 255) / 255, g = (n >> 8 & 255) / 255, b = (n & 255) / 255;
    const max = Math.max(r, g, b), d = max - Math.min(r, g, b);
    let h = 0;
    if (d) h = max === r ? ((g - b) / d) % 6 : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
    return { h: (h * 60 + 360) % 360, s: max ? d / max : 0, v: max };
}
function hsvToHex(h, s, v) {
    const f = (n) => { const k = (n + h / 60) % 6; return v - v * s * Math.max(0, Math.min(k, 4 - k, 1)); };
    return '#' + [f(5), f(3), f(1)].map(x => Math.round(x * 255).toString(16).padStart(2, '0')).join('');
}

Vue.createApp({
    data() {
        const saved = safeStorage.get(SETTINGS_POS_KEY);
        return {
            open: false,
            locales: {},
            tab: 'layout',
            allowMap: true, allowColors: true, iconColors: {},
            colorIcons: COLOR_ICONS, swatches: COLOR_SWATCHES, ringKeys: ['good', 'warn', 'bad'],
            picking: null, hsv: { h: 0, s: 0, v: 1 }, hexInput: '',
            voiceEnabled: false, deadeyeEnabled: true, bondEnabled: true, horseNeedsEnabled: true,
            limits: { minOpacity: 30, minScale: 70, maxScale: 140 },
            sizes: ['small', 'medium', 'large'],
            aligns: ['top-left', 'top-center', 'top-right', 'bottom-left', 'bottom-center', 'bottom-right'],
            orientations: ['horizontal', 'vertical'],
            mapModes: [{ key: 'off', icon: 'fa-ban' }, { key: 'map', icon: 'fa-map' }, { key: 'compass', icon: 'fa-compass' }],
            mapRows: [{ key: 'mapFoot', label: 'set_map_foot', icon: 'fa-person-walking' }, { key: 'mapMount', label: 'set_map_mount', icon: 'fa-horse' }],
            sliders: [{ key: 'opacity', label: 'set_opacity' }, { key: 'scale', label: 'set_scale' }],
            preset: { size: 'medium', align: 'bottom-center', orientation: 'horizontal', offsetX: 0, offsetY: 0, hidden: {}, display: { ...hudDisplay } },
            hideable: [
                { key: 'health', label: 'health_label' }, { key: 'stamina', label: 'stamina_label' }, { key: 'deadeye', label: 'deadeye_label', needs: 'deadeyeEnabled' },
                { key: 'hunger', label: 'hunger_label' }, { key: 'thirst', label: 'thirst_label' }, { key: 'cleanliness', label: 'clean_label' },
                { key: 'stress', label: 'stress_label' }, { key: 'temp', label: 'temp_label' }, { key: 'voice', label: 'voice_label', needs: 'voiceEnabled' },
                { key: 'mail', label: 'mail_label' }, { key: 'outlaw', label: 'outlaw_label' }, { key: 'horse', label: 'horse_health_label' },
                { key: 'horsebond', label: 'horse_bond_label', needs: 'bondEnabled' }, { key: 'horsehunger', label: 'horse_hunger_label', needs: 'horseNeedsEnabled' },
                { key: 'horsethirst', label: 'horse_thirst_label', needs: 'horseNeedsEnabled' }
            ],
            pressed: null, bumpX: false, bumpY: false,
            pos: (typeof saved.x === 'number' && typeof saved.y === 'number') ? { x: saved.x, y: saved.y } : null,
            moving: false, sliding: false, resetDone: false
        };
    },
    computed: {
        tabs() { return SETTINGS_TABS.filter(tb => !tb.needs || this[tb.needs]); },
        colorList() { return this.colorIcons.filter(k => !k.needs || this[k.needs]); },
        pickHex() { return hsvToHex(this.hsv.h, this.hsv.s, this.hsv.v); },
        hideableList() { return this.hideable.filter(k => !k.needs || this[k.needs]); },
        d() { return this.preset.display; },
        panelStyle() { return this.pos ? { left: this.pos.x + 'px', top: this.pos.y + 'px' } : {}; }
    },
    mounted() {
        document.getElementById('preset-menu').classList.remove('hidden');
        this.listener = ({ data }) => {
            if (data.action === 'setLocales') this.locales = data.locales || {};
            else if (data.action === 'setConfig') {
                this.allowMap = data.allowMap === true;
                this.allowColors = data.allowColors === true;
                this.iconColors = data.iconColors || {};
                this.voiceEnabled = data.voiceEnabled === true;
                this.deadeyeEnabled = data.deadeyeEnabled === true;
                this.bondEnabled = data.bondEnabled === true;
                this.horseNeedsEnabled = data.horseNeedsEnabled === true;
                if (data.limits) this.limits = { ...this.limits, ...data.limits };
                if (!this.tabs.some(tb => tb.key === this.tab)) this.tab = 'layout';
            }
            else if (data.action === 'openPresetMenu') {
                const p = data.preset || {};
                const disp = { ...hudDisplay, ...(p.display || {}) };
                disp.colors = (disp.colors && !Array.isArray(disp.colors)) ? { ...disp.colors } : {};
                this.preset = { ...this.preset, ...p, hidden: { ...(p.hidden || {}) }, display: disp };
                this.picking = null;
                this.resetDone = false;
                this.open = true;
                this.$nextTick(() => this.clampPos());
            }
            else if (data.action === 'closePresetMenu') this.open = false;
        };
        const ARROWS = { ArrowUp: [0, -1], ArrowDown: [0, 1], ArrowLeft: [-1, 0], ArrowRight: [1, 0] };
        this.keyListener = (e) => {
            if (!this.open) return;
            if (e.key === 'Escape') return this.cancel();
            if (e.key === 'Enter') { if (e.target && e.target.tagName === 'INPUT') { e.target.blur(); return; } return this.save(); }
            const dir = ARROWS[e.key];
            if (!dir || this.tab !== 'layout') return;
            e.preventDefault();
            this.nudge(dir[0], dir[1], e.shiftKey, e.key);
        };
        this.keyUpListener = (e) => { if (ARROWS[e.key]) this.pressed = null; };
        this.resizeListener = () => this.clampPos();
        document.addEventListener('keyup', this.keyUpListener);
        window.addEventListener('message', this.listener);
        window.addEventListener('resize', this.resizeListener);
        document.addEventListener('keydown', this.keyListener);
    },
    unmounted() {
        window.removeEventListener('message', this.listener);
        window.removeEventListener('resize', this.resizeListener);
        document.removeEventListener('keydown', this.keyListener);
        document.removeEventListener('keyup', this.keyUpListener);
    },
    methods: {
        t(key, fallback) { return this.locales[key] || fallback; },
        pick(key, value) {
            this.preset[key] = value;
            if (key === 'align') { this.preset.offsetX = 0; this.preset.offsetY = 0; } // new anchor = fresh offset
            applyPresetClasses(this.preset); // live preview
        },
        toggleHidden(key) {
            const h = { ...this.preset.hidden };
            if (h[key]) delete h[key]; else h[key] = true;
            this.preset.hidden = h;
            setHidden(h); // live preview
        },
        setDisplay(key, val) {
            this.preset.display = { ...this.preset.display, [key]: val };
            applyDisplay(this.preset.display); // live preview
        },
        toggleDisplay(key) { this.setDisplay(key, !this.preset.display[key]); },
        range(key) {
            return key === 'opacity' ? [this.limits.minOpacity || 30, 100] : [this.limits.minScale || 70, this.limits.maxScale || 140];
        },
        fillPct(key) {
            const [lo, hi] = this.range(key);
            return Math.max(0, Math.min(100, ((Number(this.d[key]) || lo) - lo) / (hi - lo) * 100));
        },
        stepDisplay(key, dir) {
            const [lo, hi] = this.range(key);
            this.setDisplay(key, Math.max(lo, Math.min(hi, (Number(this.d[key]) || 100) + dir * 5)));
        },
        startSlide(e, key) {
            if (e.button !== 0) return;
            e.preventDefault();
            const track = e.currentTarget;
            const [lo, hi] = this.range(key);
            const set = (ev) => {
                const r = track.getBoundingClientRect();
                const f = Math.max(0, Math.min(1, (ev.clientX - r.left) / r.width));
                this.setDisplay(key, Math.max(lo, Math.min(hi, Math.round((lo + f * (hi - lo)) / 5) * 5)));
            };
            const up = () => { this.sliding = false; document.removeEventListener('mousemove', set); document.removeEventListener('mouseup', up); };
            this.sliding = true;
            set(e);
            document.addEventListener('mousemove', set);
            document.addEventListener('mouseup', up);
        },
        // ---- colours ----
        defaultColor(slot) {
            const [key, part] = slot.split('.');
            if (key === 'ring') return RING_DEFAULTS[part];
            const c = this.iconColors[key] || {};
            return part === 'alert' ? (c.low || c.active || c.hasmail || c.cold || '#e0554f') : (c.normal || '#ffffff');
        },
        colorOf(slot) { return this.d.colors[slot] || this.defaultColor(slot); },
        isCustom(slot) { return !!this.d.colors[slot]; },
        hasCustom(key) { return !!(this.d.colors[key + '.normal'] || this.d.colors[key + '.alert']); },
        setColor(slot, hex) {
            const colors = { ...this.d.colors };
            if (hex && HEX_RE.test(hex) && hex.toLowerCase() !== this.defaultColor(slot).toLowerCase()) colors[slot] = hex.toLowerCase();
            else delete colors[slot];
            this.setDisplay('colors', colors);
        },
        openPicker(slot) {
            if (this.picking === slot) { this.picking = null; return; }
            this.picking = slot;
            const hex = this.colorOf(slot);
            this.hsv = hexToHsv(HEX_RE.test(hex) ? hex : '#ffffff');
            this.hexInput = hex.toUpperCase();
        },
        pickerLabel() {
            if (!this.picking) return '';
            const [key, part] = this.picking.split('.');
            if (key === 'ring') return this.t('col_rings', 'Ring Colours') + ' · ' + this.t('col_' + part, part);
            const item = this.colorIcons.find(i => i.key === key);
            return this.stripEmoji(this.t(item ? item.label : key, key)) + ' · ' + this.t(part === 'alert' ? 'col_alert' : 'col_normal', part);
        },
        commitHsv() { const hex = this.pickHex; this.hexInput = hex.toUpperCase(); this.setColor(this.picking, hex); },
        dragPick(e, kind) {
            if (e.button !== 0) return;
            e.preventDefault();
            const el = e.currentTarget;
            const set = (ev) => {
                const r = el.getBoundingClientRect();
                const x = Math.max(0, Math.min(1, (ev.clientX - r.left) / r.width));
                const y = Math.max(0, Math.min(1, (ev.clientY - r.top) / r.height));
                if (kind === 'hue') this.hsv = { ...this.hsv, h: x * 359.9 };
                else this.hsv = { ...this.hsv, s: x, v: 1 - y };
                this.commitHsv();
            };
            const up = () => { this.sliding = false; document.removeEventListener('mousemove', set); document.removeEventListener('mouseup', up); };
            this.sliding = true;
            set(e);
            document.addEventListener('mousemove', set);
            document.addEventListener('mouseup', up);
        },
        pickSwatch(hex) { this.hsv = hexToHsv(hex); this.commitHsv(); },
        typeHex() {
            let v = this.hexInput.trim();
            if (!v.startsWith('#')) v = '#' + v;
            if (HEX_RE.test(v)) { this.hsv = hexToHsv(v); this.setColor(this.picking, v); }
        },
        defaultPicked() {
            const def = this.defaultColor(this.picking);
            this.setColor(this.picking, null);
            this.hsv = hexToHsv(def);
            this.hexInput = def.toUpperCase();
        },
        resetIconColors(key) {
            this.setColor(key + '.normal', null);
            this.setColor(key + '.alert', null);
            if (this.picking && this.picking.startsWith(key + '.')) {
                const def = this.defaultColor(this.picking);
                this.hsv = hexToHsv(def);
                this.hexInput = def.toUpperCase();
            }
        },
        resetAllColors() { this.picking = null; this.setDisplay('colors', {}); },
        // ---- movable window ----
        clampXY(x, y, w, h) {
            return { x: Math.round(Math.max(0, Math.min(x, window.innerWidth - w))), y: Math.round(Math.max(0, Math.min(y, window.innerHeight - h))) };
        },
        clampPos() {
            const panel = this.$refs.panel;
            if (!this.pos || !panel) return;
            const r = panel.getBoundingClientRect();
            this.pos = this.clampXY(this.pos.x, this.pos.y, r.width, r.height);
        },
        startMove(e) {
            if (e.button !== 0 || e.target.closest('button')) return;
            e.preventDefault();
            const panel = this.$refs.panel;
            if (!panel) return;
            const r = panel.getBoundingClientRect();
            const ox = e.clientX - r.left, oy = e.clientY - r.top;
            const move = (ev) => { this.pos = this.clampXY(ev.clientX - ox, ev.clientY - oy, r.width, r.height); };
            const up = () => {
                this.moving = false;
                document.removeEventListener('mousemove', move);
                document.removeEventListener('mouseup', up);
                if (this.pos) safeStorage.set(SETTINGS_POS_KEY, this.pos);
            };
            this.moving = true;
            this.pos = { x: Math.round(r.left), y: Math.round(r.top) };
            document.addEventListener('mousemove', move);
            document.addEventListener('mouseup', up);
        },
        centerPanel(e) {
            if (e && e.target.closest('button')) return;
            this.pos = null;
            safeStorage.set(SETTINGS_POS_KEY, {});
        },
        // ---- layout offset ----
        stripEmoji(s) { return String(s).replace(/[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]/gu, '').trim(); },
        fmt(v) { v = Math.round(v || 0); return (v > 0 ? '+' : '') + v + 'px'; },
        nudge(dx, dy, big, key) {
            const step = big ? 20 : 4;
            const limX = Math.round(window.innerWidth * 0.9), limY = Math.round(window.innerHeight * 0.9);
            this.preset.offsetX = Math.max(-limX, Math.min(limX, (this.preset.offsetX || 0) + dx * step));
            this.preset.offsetY = Math.max(-limY, Math.min(limY, (this.preset.offsetY || 0) + dy * step));
            if (key) this.pressed = key;
            this.flashBump(dx ? 'bumpX' : 'bumpY');
            applyPresetClasses(this.preset);
        },
        flashBump(flag) {
            this[flag] = false;
            requestAnimationFrame(() => { this[flag] = true; });
            clearTimeout(this['t_' + flag]);
            this['t_' + flag] = setTimeout(() => { this[flag] = false; }, 180);
        },
        resetOffset() { this.preset.offsetX = 0; this.preset.offsetY = 0; applyPresetClasses(this.preset); },
        // ---- icon positions ----
        editIcons() { this.open = false; this.pressed = null; nuiPost('savePreset', { ...this.preset, thenEdit: true }); },
        resetPositions() {
            hudDrag.resetToDefaults();
            this.resetDone = true;
            clearTimeout(this.resetTimer);
            this.resetTimer = setTimeout(() => { this.resetDone = false; }, 2500);
        },
        // ---- save / cancel ----
        save() { if (this.sliding) return; this.open = false; this.pressed = null; nuiPost('savePreset', { ...this.preset }); },
        cancel() { this.open = false; this.pressed = null; nuiPost('closePresetMenu'); }
    }
}).mount('#preset-menu');

// ============ LAYOUT PRESETS (size / position / orientation) ============
window.addEventListener('message', ({ data }) => {
    if (data.action !== 'applyPreset' || !data.preset) return;
    const p = data.preset;
    applyPresetClasses(p);
    setHidden(p.hidden);
    applyDisplay(p.display);
    if (data.clearCustom) hudDrag.clearStatLayout();
});

// Tell Lua the NUI is ready so it can send locales + colours
nuiPost('nuiReady');
