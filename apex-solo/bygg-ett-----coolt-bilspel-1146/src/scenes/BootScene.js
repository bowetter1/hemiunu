/**
 * GRAVSHIFT - Boot Scene
 * Initial loading and configuration
 */

class BootScene extends Phaser.Scene {
    constructor() {
        super({ key: 'BootScene' });
    }
    
    init() {
        // Initialize game registry with default values
        this.registry.set('masterVolume', GAME_CONFIG.AUDIO.MASTER_VOLUME);
        this.registry.set('musicVolume', GAME_CONFIG.AUDIO.MUSIC_VOLUME);
        this.registry.set('sfxVolume', GAME_CONFIG.AUDIO.SFX_VOLUME);
        this.registry.set('muted', false);
        this.registry.set('selectedVehicle', 'BALANCED');
        this.registry.set('currentLevel', 1);
        
        // Load saved settings
        this.loadSettings();
    }
    
    preload() {
        // Load minimal assets needed for preload screen
        // We'll generate most graphics procedurally for the neon aesthetic
    }
    
    create() {
        // Configure game scaling
        this.scale.on('resize', this.handleResize, this);
        
        // Setup global event handlers
        this.setupGlobalEvents();
        
        // Detect input method
        this.detectInputMethod();
        
        // Initialize audio context on first interaction
        this.input.once('pointerdown', () => {
            this.registry.set('audioInitialized', true);
        });
        
        this.input.keyboard.once('keydown', () => {
            this.registry.set('audioInitialized', true);
        });
        
        // Proceed to preload scene
        this.scene.start('PreloadScene');
    }
    
    loadSettings() {
        try {
            const settingsData = localStorage.getItem(GAME_CONFIG.STORAGE.SETTINGS);
            if (settingsData) {
                const settings = JSON.parse(settingsData);
                this.registry.set('masterVolume', settings.masterVolume ?? GAME_CONFIG.AUDIO.MASTER_VOLUME);
                this.registry.set('musicVolume', settings.musicVolume ?? GAME_CONFIG.AUDIO.MUSIC_VOLUME);
                this.registry.set('sfxVolume', settings.sfxVolume ?? GAME_CONFIG.AUDIO.SFX_VOLUME);
                this.registry.set('muted', settings.muted ?? false);
                this.registry.set('selectedVehicle', settings.selectedVehicle ?? 'BALANCED');
            }
        } catch (e) {
            console.warn('Could not load settings:', e);
        }
    }
    
    setupGlobalEvents() {
        // Handle visibility change (tab switching)
        document.addEventListener('visibilitychange', () => {
            if (document.hidden) {
                this.game.events.emit('gamePaused');
            } else {
                this.game.events.emit('gameResumed');
            }
        });
        
        // Handle window blur/focus
        window.addEventListener('blur', () => {
            this.game.events.emit('windowBlur');
        });
        
        window.addEventListener('focus', () => {
            this.game.events.emit('windowFocus');
        });
    }
    
    detectInputMethod() {
        // Check for touch support
        const hasTouch = 'ontouchstart' in window || navigator.maxTouchPoints > 0;
        this.registry.set('hasTouch', hasTouch);
        
        // Check for gamepad
        const hasGamepad = navigator.getGamepads && navigator.getGamepads()[0];
        this.registry.set('hasGamepad', !!hasGamepad);
        
        // Listen for gamepad connection
        window.addEventListener('gamepadconnected', () => {
            this.registry.set('hasGamepad', true);
        });
    }
    
    handleResize(gameSize) {
        // Emit resize event for scenes to handle
        this.game.events.emit('resize', gameSize);
    }
}

// Export
if (typeof window !== 'undefined') {
    window.BootScene = BootScene;
}
