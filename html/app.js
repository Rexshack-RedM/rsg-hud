// MONEY HUD

const moneyHud = Vue.createApp({
    data() {
        return {
            cash: 0,
            bloodmoney: 0,
            bank: 0,
            amount: 0,
            plus: false,
            minus: false,
            showCash: false,
            showBloodmoney: false,
            showBank: false,
            showUpdate: false,
            editMode: false,
            locales: {}
        }
    },
    destroyed() {
        window.removeEventListener('message', this.listener);
    },
    mounted() {
        this.listener = window.addEventListener('message', (event) => {
            switch (event.data.action) {
                case 'showconstant':
                    this.showConstant(event.data)
                    break;
                case 'update':
                    this.update(event.data)
                    break;
                case 'show':
                    this.showAccounts(event.data)
                    break;
                case 'toggleEditMode':
                    this.editMode = event.data.enabled
                    break;
                case 'setLocales':
                    this.locales = event.data.locales
                    break;
            }
        });
    },
    methods: {
        // CONFIGURE YOUR CURRENCY HERE
        // https://www.w3schools.com/tags/ref_language_codes.asp LANGUAGE CODES
        // https://www.w3schools.com/tags/ref_country_codes.asp COUNTRY CODES
        formatMoney(value) {
            const formatter = new Intl.NumberFormat('en-US', {
                style: 'currency',
                currency: 'USD',
                minimumFractionDigits: 0
            });
            return formatter.format(value);
        },
        showConstant(data) {
            this.showCash = true;
            this.showBloodmoney = true;
            this.showBank = true;
            this.cash = data.cash;
            this.bloodmoney = data.bloodmoney;
            this.bank = data.bank;
        },
        update(data) {
            this.showUpdate = true;
            this.amount = data.amount;
            this.bank = data.bank;
            this.bloodmoney = data.bloodmoney;
            this.cash = data.cash;
            this.minus = data.minus;
            this.plus = data.plus;
            if (data.type === 'cash') {
                if (data.minus) {
                    this.showCash = true;
                    this.minus = true;
                    setTimeout(() => this.showUpdate = false, 1000)
                    setTimeout(() => this.showCash = false, 2000)
                } else {
                    this.showCash = true;
                    this.plus = true;
                    setTimeout(() => this.showUpdate = false, 1000)
                    setTimeout(() => this.showCash = false, 2000)
                }
            }
            if (data.type === 'bloodmoney') {
                if (data.minus) {
                    this.showBloodmoney = true;
                    this.minus = true;
                    setTimeout(() => this.showUpdate = false, 1000)
                    setTimeout(() => this.showBloodmoney = false, 2000)
                } else {
                    this.showBloodmoney = true;
                    this.plus = true;
                    setTimeout(() => this.showUpdate = false, 1000)
                    setTimeout(() => this.showBloodmoney = false, 2000)
                }
            }
            if (data.type === 'bank') {
                if (data.minus) {
                    this.showBank = true;
                    this.minus = true;
                    setTimeout(() => this.showUpdate = false, 1000)
                    setTimeout(() => this.showBank = false, 2000)
                } else {
                    this.showBank = true;
                    this.plus = true;
                    setTimeout(() => this.showUpdate = false, 1000)
                    setTimeout(() => this.showBank = false, 2000)
                }
            }
        },
        showAccounts(data) {
            if (data.type === 'cash' && !this.showCash) {
                this.showCash = true;
                this.cash = data.cash;
                setTimeout(() => this.showCash = false, 3500);
            }
            else if (data.type === 'bloodmoney' && !this.showBloodmoney) {
                this.showBloodmoney = true;
                this.bloodmoney = data.bloodmoney;
                setTimeout(() => this.showBloodmoney = false, 3500);
            }
            else if (data.type === 'bank' && !this.showBank) {
                this.showBank = true;
                this.bank = data.bank;
                setTimeout(() => this.showBank = false, 3500);
            }
        }
    }
}).mount('#money-container')

// PLAYER HUD

const playerHud = {
    data() {
        return {
            health: 0,
            stamina: 0,
            armor: 0,
            hunger: 0,
            thirst: 0,
            cleanliness: 0,
            stress: 0,
            voice: 0,
            temp: 0,
            horsehealth: 0,
            horsestamina: 0,
            horseclean: 0,
            youhavemail: false,
            outlawstatus: true,
            show: false,
            talking: false,
            showVoice: true,
            showHealth: true,
            showStamina: true,
            showArmor: true,
            showHunger: true,
            showThirst: true,
            showCleanliness: true,
            showStress: true,
            showHorseStamina: false,
            showHorseHealth: false,
            showHorseClean: false,
            showHorseStaminaColor: "#a16600",
            showHorseHealthColor: "#a16600",
            showHorseCleanColor: "#a16600",
            showYouHaveMail: true,
            talkingColor: "#FFFFFF",
            showTemp: true,
            editMode: false,
            iconColors: {}, // Store config colors
            savedVisibility: null, // Store visibility states for edit mode
            locales: {} // Store locale translations
        }
    },
    destroyed() {
        window.removeEventListener('message', this.listener);
    },
    mounted() {
        this.listener = window.addEventListener('message', (event) => {
            if (event.data.action === 'hudtick') {
                this.hudTick(event.data);
            } else if (event.data.action === 'toggleEditMode') {
                this.toggleEditMode(event.data.enabled);
            } else if (event.data.action === 'setLocales') {
                this.locales = event.data.locales;
            }
        });
    },
    methods: {
        hudTick(data) {
            this.show = data.show;
            this.health = data.health;
            this.stamina = parseInt(data.stamina);
            this.armor = data.armor;
            this.hunger = data.hunger;
            this.thirst = data.thirst;
            this.cleanliness = data.cleanliness;
            this.stress = data.stress;
            this.voice = data.voice;
            this.temp = data.temp;
            this.youhavemail = data.youhavemail;
            this.outlawstatus = data.outlawstatus;
            this.talking = data.talking;
            
            // Don't modify horse visibility if in edit mode
            if (!this.editMode) {
                this.showHorseStamina = data.onHorse;
                this.showHorseHealth = data.onHorse;
                this.showHorseClean = data.onHorse;
            }
            
            // Store config colors if provided
            if (data.iconColors) {
                this.iconColors = data.iconColors;
            }
            
            if (data.onHorse) {
                this.horsehealth = data.horsehealth;
                this.horsestamina = data.horsestamina;
                this.horseclean = data.horseclean;
                
                // Set horse colors based on config
                this.showHorseHealthColor = (data.horsehealth <= 30) ?
                    (this.iconColors.horse_health?.low || "#FF0000") :
                    (this.iconColors.horse_health?.normal || "#a16600");
                    
                this.showHorseStaminaColor = (data.horsestamina <= 30) ?
                    (this.iconColors.horse_stamina?.low || "#FF0000") :
                    (this.iconColors.horse_stamina?.normal || "#a16600");
                    
                this.showHorseCleanColor = (data.horseclean <= 30) ?
                    (this.iconColors.horse_clean?.low || "#FF0000") :
                    (this.iconColors.horse_clean?.normal || "#a16600");
            }
            
            // Don't modify visibility if in edit mode
            if (!this.editMode) {
                if (data.health >= 100) {
                    this.showHealth = false;
                } else {
                    this.showHealth = true;
                }
            }
            
            if (data.health <= 30) {
                this.showHealthColor = this.iconColors.health?.low || "#FF0000";
            } else {
                this.showHealthColor = this.iconColors.health?.normal || "#FFFFFF";
            }
            
            // Don't modify visibility if in edit mode
            if (!this.editMode) {
                if (parseInt(data.stamina) >= 100) {
                    this.showStamina = false;
                } else {
                    this.showStamina = true;
                }
            }
            
            if (parseInt(data.stamina) <= 30) {
                this.showStaminaColor = this.iconColors.stamina?.low || "#FF0000";
            } else {
                this.showStaminaColor = this.iconColors.stamina?.normal || "#FFFFFF";
            }
            if (data.hunger <= 30) {
                this.showHungerColor = this.iconColors.hunger?.low || "#FF0000";
            } else {
                this.showHungerColor = this.iconColors.hunger?.normal || "#FFFFFF";
            }
            
            if (data.thirst <= 30) {
                this.showThirstColor = this.iconColors.thirst?.low || "#FF0000";
            } else {
                this.showThirstColor = this.iconColors.thirst?.normal || "#FFFFFF";
            }
            
            if (data.cleanliness <= 30) {
                this.showCleanlinessColor = this.iconColors.cleanliness?.low || "#FF0000";
            } else {
                this.showCleanlinessColor = this.iconColors.cleanliness?.normal || "#FFFFFF";
            }
            
            // Don't modify visibility if in edit mode
            if (!this.editMode) {
                if (data.armor <= 0) {
                    this.showArmor = false;
                } else {
                    this.showArmor = true;
                }
                
                if (data.hunger >= 100) {
                    this.showHunger = false;
                } else {
                    this.showHunger = true;
                }
                
                if (data.thirst >= 100) {
                    this.showThirst = false;
                } else {
                    this.showThirst = true;
                }
                
                if (data.cleanliness >= 100) {
                    this.showCleanliness = false;
                } else {
                    this.showCleanliness = true;
                }
                
                if (data.stress <= 0) {
                    this.showStress = false;
                } else {
                    this.showStress = true;
                }
                
                if (data.youhavemail) {
                    this.showYouHaveMail = true;
                } else {
                    this.showYouHaveMail = false;
                }
            }
            
            // Voice visibility - configurable
            if (data.voiceAlwaysVisible) {
                this.showVoice = true;  // Always visible if config enabled
            } else {
                // Only visible when talking if config disabled
                if (data.talking) {
                    this.showVoice = true;
                } else {
                    this.showVoice = false;
                }
            }
            if (data.talking) {
                this.talkingColor = this.iconColors.voice?.active || "#FF0000";
            } else {
                this.talkingColor = this.iconColors.voice?.normal || "#FFFFFF";
            }
            // Temp always visible
            if (data.temp >= 0) {
                this.showTemp = true;
            } else {
                this.showTemp = true;
            }
            if (data.temp <= 30) {
                this.showTempColor = this.iconColors.temp?.cold || "#FDD021";
            } else {
                this.showTempColor = this.iconColors.temp?.normal || "#CFBCAE";
            }
            if (data.youhavemail) {
                this.showYouHaveMailColor = this.iconColors.mail?.hasmail || "#FFD700";
            } else {
                this.showYouHaveMailColor = this.iconColors.mail?.normal || "#FFFFFF";
            }
            
            // Don't modify outlaw visibility if in edit mode
            if (!this.editMode) {
                if (data.outlawstatus >= 100) {
                    this.showoutlawstatus = true;
                } else {
                    this.showoutlawstatus = false;
                }
            }
            
            if (data.outlawstatus) {
                this.showOutLawColor = this.iconColors.outlaw?.active || "#FF0000";
            } else {
                this.showOutLawColor = this.iconColors.outlaw?.normal || "#00FF00";
            }
        },
        
        // Toggle edit mode and manage element visibility
        toggleEditMode(enabled) {
            this.editMode = enabled;
            
            // When entering edit mode, show all elements temporarily
            if (enabled) {
                // Store current visibility states BEFORE forcing them to true
                this.savedVisibility = {
                    showHealth: this.showHealth,
                    showStamina: this.showStamina,
                    showHunger: this.showHunger,
                    showThirst: this.showThirst,
                    showCleanliness: this.showCleanliness,
                    showStress: this.showStress,
                    showYouHaveMail: this.showYouHaveMail,
                    showHorseHealth: this.showHorseHealth,
                    showHorseStamina: this.showHorseStamina,
                    showHorseClean: this.showHorseClean,
                    showTemp: this.showTemp,
                    showoutlawstatus: this.showoutlawstatus
                };
                
                // Force show all elements in edit mode
                this.showHealth = true;
                this.showStamina = true;
                this.showHunger = true;
                this.showThirst = true;
                this.showCleanliness = true;
                this.showStress = true;
                this.showYouHaveMail = true;
                this.showHorseHealth = true;
                this.showHorseStamina = true;
                this.showHorseClean = true;
                this.showTemp = true;
                this.showoutlawstatus = true;
            } else {
                // Restore original visibility states when exiting edit mode
                if (this.savedVisibility) {
                    this.showHealth = this.savedVisibility.showHealth;
                    this.showStamina = this.savedVisibility.showStamina;
                    this.showHunger = this.savedVisibility.showHunger;
                    this.showThirst = this.savedVisibility.showThirst;
                    this.showCleanliness = this.savedVisibility.showCleanliness;
                    this.showStress = this.savedVisibility.showStress;
                    this.showYouHaveMail = this.savedVisibility.showYouHaveMail;
                    this.showHorseHealth = this.savedVisibility.showHorseHealth;
                    this.showHorseStamina = this.savedVisibility.showHorseStamina;
                    this.showHorseClean = this.savedVisibility.showHorseClean;
                    this.showTemp = this.savedVisibility.showTemp;
                    this.showoutlawstatus = this.savedVisibility.showoutlawstatus;
                    this.savedVisibility = null;
                }
            }
        }
    }
}
const app = Vue.createApp(playerHud);
app.use(Quasar)
app.mount('#ui-container');


// HUD DRAGGING SYSTEM
class HUDDragSystem {
    constructor() {
        this.isDragging = false;
        this.isResizing = false;
        this.currentElement = null;
        this.dragOffset = { x: 0, y: 0 };
        this.editMode = false;
        this.positions = this.loadPositions();
        this.sizes = this.loadSizes();
        
        this.init();
    }
    
    init() {
        // Load saved positions
        this.applyPositions();
        
        // Set up event listeners
        document.addEventListener('mousedown', this.handleMouseDown.bind(this));
        document.addEventListener('mousemove', this.handleMouseMove.bind(this));
        document.addEventListener('mouseup', this.handleMouseUp.bind(this));
        // Add mouseleave to handle cases where mouse leaves window while dragging
        document.addEventListener('mouseleave', this.handleMouseUp.bind(this));
        // Add window blur event to stop dragging when window loses focus
        window.addEventListener('blur', this.handleMouseUp.bind(this));
        // Add ESC key to cancel dragging
        document.addEventListener('keydown', this.handleKeyDown.bind(this));
        
        // Listen for edit mode changes and reset commands
        window.addEventListener('message', (event) => {
            if (event.data.action === 'toggleEditMode') {
                this.toggleEditMode(event.data.enabled);
            } else if (event.data.action === 'resetPositions') {
                this.resetToDefaults();
            }
        });
    }
    
    loadPositions() {
        const saved = localStorage.getItem('hudPositions');
        if (saved) {
            try {
                return JSON.parse(saved);
            } catch (e) {
                console.warn('Failed to parse saved HUD positions:', e);
            }
        }
        return {};
    }
    
    savePositions() {
        localStorage.setItem('hudPositions', JSON.stringify(this.positions));
    }
    
    loadSizes() {
        const saved = localStorage.getItem('hudSizes');
        if (saved) {
            try {
                return JSON.parse(saved);
            } catch (e) {
                console.warn('Failed to parse saved HUD sizes:', e);
            }
        }
        return {};
    }
    
    saveSizes() {
        localStorage.setItem('hudSizes', JSON.stringify(this.sizes));
    }
    
    applyPositions() {
        Object.keys(this.positions).forEach(elementName => {
            const element = document.querySelector(`[data-element="${elementName}"]`);
            if (element && this.positions[elementName]) {
                const pos = this.positions[elementName];
                // For status circles, use fixed positioning
                if (element.classList.contains('status-circle')) {
                    element.style.position = 'fixed';
                    element.style.left = pos.x + 'px';
                    element.style.top = pos.y + 'px';
                    element.style.right = 'auto';
                    element.style.bottom = 'auto';
                } else {
                    // For containers like money
                    element.style.position = 'absolute';
                    element.style.left = pos.x + 'px';
                    element.style.top = pos.y + 'px';
                    element.style.right = 'auto';
                    element.style.bottom = 'auto';
                }
            }
        });
        
        // Apply saved sizes
        Object.keys(this.sizes).forEach(elementName => {
            const element = document.querySelector(`[data-element="${elementName}"]`);
            if (element && this.sizes[elementName]) {
                const size = this.sizes[elementName];
                this.applySizeToElement(element, size);
            }
        });
    }
    
    toggleEditMode(enabled) {
        this.editMode = enabled;
        const draggableElements = document.querySelectorAll('.draggable-element');
        
        draggableElements.forEach(element => {
            if (enabled) {
                element.classList.add('edit-mode');
            } else {
                element.classList.remove('edit-mode');
                element.classList.remove('dragging');
            }
        });
        
        // Stop any current dragging/resizing and reset cursor
        if (!enabled) {
            this.stopDragging();
            this.stopResizing();
            // Force reset cursor and user selection
            document.body.style.cursor = '';
            document.body.style.userSelect = '';
            this.isDragging = false;
            this.isResizing = false;
            this.currentElement = null;
        }
    }
    
    handleMouseDown(e) {
        if (!this.editMode) return;
        
        // Check if clicked on a resize handle
        if (e.target.classList.contains('resize-handle')) {
            e.preventDefault();
            this.startResizing(e.target.parentElement, e);
        }
        // Check if clicked on a status circle or its contents (but not resize handle)
        else {
            // Find the nearest status circle container
            let statusCircle = e.target.closest('.status-circle');
            if (statusCircle && !e.target.classList.contains('resize-handle')) {
                e.preventDefault();
                this.startDragging(statusCircle, e);
            }
        }
    }
    
    startDragging(element, e) {
        this.isDragging = true;
        this.currentElement = element;
        element.classList.add('dragging');
        
        const rect = element.getBoundingClientRect();
        this.dragOffset = {
            x: e.clientX - rect.left,
            y: e.clientY - rect.top
        };
        
        // Set positioning based on element type
        if (element.classList.contains('status-circle')) {
            element.style.position = 'fixed';
            element.style.left = rect.left + 'px';
            element.style.top = rect.top + 'px';
            element.style.right = 'auto';
            element.style.bottom = 'auto';
        } else {
            // For containers like money
            element.style.position = 'absolute';
            element.style.left = rect.left + 'px';
            element.style.top = rect.top + 'px';
            element.style.right = 'auto';
            element.style.bottom = 'auto';
        }
        
        // Disable text selection during drag
        document.body.style.userSelect = 'none';
    }
    
    handleMouseMove(e) {
        if (this.isDragging && this.currentElement) {
            e.preventDefault();
            
            const newX = e.clientX - this.dragOffset.x;
            const newY = e.clientY - this.dragOffset.y;
            
            // Keep element within viewport bounds
            const viewportWidth = window.innerWidth;
            const viewportHeight = window.innerHeight;
            const elementRect = this.currentElement.getBoundingClientRect();
            
            const clampedX = Math.max(0, Math.min(newX, viewportWidth - elementRect.width));
            const clampedY = Math.max(0, Math.min(newY, viewportHeight - elementRect.height));
            
            this.currentElement.style.left = clampedX + 'px';
            this.currentElement.style.top = clampedY + 'px';
        }
        else if (this.isResizing && this.currentElement) {
            e.preventDefault();
            this.handleResize(e);
        }
    }
    
    handleMouseUp(e) {
        if (this.isDragging) {
            this.stopDragging();
        } else if (this.isResizing) {
            this.stopResizing();
        }
    }
    
    handleKeyDown(e) {
        // ESC key cancels dragging or exits edit mode
        if (e.key === 'Escape') {
            if (this.isDragging) {
                this.stopDragging();
            } else if (this.editMode) {
                // Exit edit mode via NUI callback
                fetch(`https://${GetParentResourceName()}/disableEditMode`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json; charset=UTF-8',
                    },
                    body: JSON.stringify({})
                });
            }
        }
    }
    
    startResizing(element, e) {
        this.isResizing = true;
        this.currentElement = element;
        element.classList.add('resizing');
        
        this.initialMouseX = e.clientX;
        this.initialMouseY = e.clientY;
        
        const rect = element.getBoundingClientRect();
        this.initialWidth = rect.width;
        this.initialHeight = rect.height;
        
        document.body.style.userSelect = 'none';
        document.body.style.cursor = 'nw-resize';
    }
    
    handleResize(e) {
        if (!this.currentElement) return;
        
        const deltaX = e.clientX - this.initialMouseX;
        const deltaY = e.clientY - this.initialMouseY;
        
        // Calculate new size (use the larger delta for uniform scaling)
        const delta = Math.max(deltaX, deltaY);
        const newSize = Math.max(30, this.initialWidth + delta); // Minimum size of 30px
        const maxSize = Math.min(window.innerWidth, window.innerHeight) * 0.3; // Max 30% of viewport
        const clampedSize = Math.min(newSize, maxSize);
        
        this.applySizeToElement(this.currentElement, clampedSize);
    }
    
    applySizeToElement(element, size) {
        // Calculate scale factor based on default size (~60px)
        const baseSize = 60;
        const scaleFactor = size / baseSize;
        
        // Use CSS transform to scale the entire element
        element.style.transform = `scale(${scaleFactor})`;
        element.style.transformOrigin = 'center center';
        
        // Update the container size for collision detection
        element.style.width = size + 'px';
        element.style.height = size + 'px';
        
        // Ensure the element maintains its visual appearance
        element.style.display = 'inline-block';
    }
    
    stopResizing() {
        if (this.currentElement) {
            this.currentElement.classList.remove('resizing');
            
            // Save the new size
            const elementName = this.currentElement.getAttribute('data-element');
            if (elementName) {
                const rect = this.currentElement.getBoundingClientRect();
                this.sizes[elementName] = rect.width;
                this.saveSizes();
            }
        }
        
        // Complete cleanup
        this.isResizing = false;
        this.currentElement = null;
        document.body.style.userSelect = '';
        document.body.style.cursor = '';
        document.body.style.webkitUserSelect = '';
        document.body.style.mozUserSelect = '';
        document.body.style.msUserSelect = '';
    }
    
    stopDragging() {
        if (this.currentElement) {
            this.currentElement.classList.remove('dragging');
            
            // Save the new position
            const elementName = this.currentElement.getAttribute('data-element');
            if (elementName) {
                const rect = this.currentElement.getBoundingClientRect();
                this.positions[elementName] = {
                    x: parseInt(this.currentElement.style.left),
                    y: parseInt(this.currentElement.style.top)
                };
                this.savePositions();
            }
        }
        
        // Complete cleanup
        this.isDragging = false;
        this.currentElement = null;
        document.body.style.userSelect = '';
        document.body.style.cursor = '';
        document.body.style.webkitUserSelect = '';
        document.body.style.mozUserSelect = '';
        document.body.style.msUserSelect = '';
    }
    
    resetToDefaults() {
        // Reset money container to original position (top-right)
        const moneyContainer = document.getElementById('money-container');
        if (moneyContainer) {
            moneyContainer.style.position = 'absolute';
            moneyContainer.style.right = '2vw';
            moneyContainer.style.top = '5vh';
            moneyContainer.style.left = 'auto';
            moneyContainer.style.bottom = 'auto';
            moneyContainer.style.width = '';
            moneyContainer.style.height = '';
        }
        
        // Reset ui-container to lower position (bottom-left, but lower than original)
        const uiContainer = document.getElementById('ui-container');
        if (uiContainer) {
            uiContainer.style.position = 'fixed';
            uiContainer.style.left = '1vh';
            uiContainer.style.bottom = '2.5vw'; // Lowered from 2.5vw to 8vh for better positioning
            uiContainer.style.right = 'auto';
            uiContainer.style.top = 'auto';
            uiContainer.style.display = 'flex';
            uiContainer.style.flexDirection = 'column';
            uiContainer.style.gap = '5px';
        }
        
        // Reset all status circle elements to their default container positioning
        const statusCircles = document.querySelectorAll('.status-circle');
        statusCircles.forEach(circle => {
            // Clear position overrides
            circle.style.position = '';
            circle.style.left = '';
            circle.style.top = '';
            circle.style.right = '';
            circle.style.bottom = '';
            circle.style.width = '';
            circle.style.height = '';
            circle.style.transform = ''; // Clear transform scaling
            circle.style.transformOrigin = '';            
            // Remove any drag/resize classes
            circle.classList.remove('edit-mode', 'dragging', 'resizing');
        });
        
        // Clear saved positions and sizes
        this.positions = {};
        this.sizes = {};
        this.savePositions();
        this.saveSizes();
    }
}

// Helper function to get resource name
function GetParentResourceName() {
    // For RedM/FiveM NUI, the resource name is typically available in the URL
    const url = window.location.href;
    const match = url.match(/nui:\/\/([^/]+)/);
    return match ? match[1] : 'rsg-hud';
}

// Initialize the drag system
const hudDragSystem = new HUDDragSystem();

// Global function to reset HUD positions (can be called from Lua)
window.resetHUDPositions = () => {
    hudDragSystem.resetToDefaults();
};

// LOGO APP
const logoApp = Vue.createApp({
    data() {
        return {
            logoConfig: {
                showLogo: false,
                logoPosition: 'top-left',
                logoName: 'logoEx.png',
                logoSize: 200,
                logoOpacity: 1.0
            }
        }
    },
    destroyed() {
        window.removeEventListener('message', this.listener);
    },
    mounted() {
        this.listener = window.addEventListener('message', (event) => {
            if (event.data.action === 'setLogoConfig') {
                this.logoConfig = event.data.logoConfig;
            }
        });
    }
}).mount('#logo-app');
