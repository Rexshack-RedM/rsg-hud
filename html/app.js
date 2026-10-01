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
            voiceAlwaysVisible: true,
            showPct: true,
            iconColors: {},
            locales: {},
            health: 0, stamina: 0, hunger: 0, thirst: 0, cleanliness: 0, stress: 0,
            temp: '0°C',
            onHorse: false, horsehealth: 0, horsestamina: 0, horseclean: 0,
            talking: false, youhavemail: false, outlawstatus: 0
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
                    this.voiceAlwaysVisible = data.voiceAlwaysVisible !== false;
                    {
                        // player's saved choice wins over the server default
                        let saved = safeStorage.get('rsghud_showpct');
                        if (typeof saved.value !== 'boolean') saved = safeStorage.get('rexhud_showpct'); // migrate old key
                        this.showPct = typeof saved.value === 'boolean' ? saved.value : data.showPercentages !== false;
                    }
                    break;
                case 'togglePercentages':
                    this.showPct = !this.showPct;
                    safeStorage.set('rsghud_showpct', { value: this.showPct });
                    break;
            }
        };
        window.addEventListener('message', this.listener);
    },
    unmounted() { window.removeEventListener('message', this.listener); },
    computed: {
        // visibility: elements hide when "full"/irrelevant, edit mode forces everything on
        vis() {
            const e = this.editMode;
            return {
                health: e || this.health < 100,
                stamina: e || this.stamina < 100,
                hunger: e || this.hunger < 100,
                thirst: e || this.thirst < 100,
                cleanliness: e || this.cleanliness < 100,
                stress: e || this.stress > 0,
                temp: true,
                horse: e || this.onHorse,
                voice: e || this.voiceAlwaysVisible || this.talking,
                mail: e || this.youhavemail,
                outlaw: e || this.isOutlaw
            };
        },
        isOutlaw() { return this.outlawstatus >= 100; },
        tempValue() { return parseFloat(this.temp) || 0; },
        isFahrenheit() { return String(this.temp).includes('F'); },
        tempCelsius() { return this.isFahrenheit ? (this.tempValue - 32) * 5 / 9 : this.tempValue; },
        tempClass() {
            const c = this.tempCelsius;
            if (c <= 0 || c >= 40) return 'stat-bad';
            if (c <= 10 || c >= 30) return 'stat-warn';
            return 'stat-good';
        },
        tempPct() { return this.clampPct((this.tempCelsius + 10) / 50 * 100); },
        tempColor() {
            const c = this.iconColors.temp || {};
            return this.tempCelsius <= 10 ? (c.cold || '#d9a441') : (c.normal || '#f2f2f2');
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
            this.onHorse = data.onHorse;
            if (data.onHorse) {
                this.horsehealth = data.horsehealth;
                this.horsestamina = data.horsestamina;
                this.horseclean = data.horseclean;
            }
        }
    }
}).mount('#ui-container');

// ============ HUD DRAG / RESIZE (edit mode) ============
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
        if (el.classList.contains('stat-circle')) {
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

    resetToDefaults() {
        this.stop();
        document.querySelectorAll('#money-container, .stat-row, .mini-badge').forEach(el => {
            ['position', 'left', 'top', 'right', 'bottom', 'width', 'height', 'transform', 'transformOrigin', 'display']
                .forEach(p => { el.style[p] = ''; });
            el.classList.remove('dragging', 'resizing');
        });
        this.positions = {};
        this.sizes = {};
        safeStorage.set('hudPositions', this.positions);
        safeStorage.set('hudSizes', this.sizes);
    }
}

new HUDDragSystem();

// Tell Lua the NUI is ready so it can send locales + colours
nuiPost('nuiReady');
