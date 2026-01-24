/**
 * GRAVSHIFT - Audio Manager
 * Handles all game audio with Web Audio API
 */

class AudioManager {
    constructor(scene) {
        this.scene = scene;
        this.sounds = {};
        this.music = null;
        this.currentMusicKey = null;
        
        // Load settings
        this.loadSettings();
        
        // Create audio context
        this.context = null;
        this.masterGain = null;
        this.musicGain = null;
        this.sfxGain = null;
        
        // Initialize on first user interaction
        this.initialized = false;
    }
    
    loadSettings() {
        try {
            const data = localStorage.getItem(GAME_CONFIG.STORAGE.SETTINGS);
            const settings = data ? JSON.parse(data) : {};
            this.masterVolume = settings.masterVolume ?? GAME_CONFIG.AUDIO.MASTER_VOLUME;
            this.musicVolume = settings.musicVolume ?? GAME_CONFIG.AUDIO.MUSIC_VOLUME;
            this.sfxVolume = settings.sfxVolume ?? GAME_CONFIG.AUDIO.SFX_VOLUME;
            this.muted = settings.muted ?? false;
        } catch (e) {
            this.masterVolume = GAME_CONFIG.AUDIO.MASTER_VOLUME;
            this.musicVolume = GAME_CONFIG.AUDIO.MUSIC_VOLUME;
            this.sfxVolume = GAME_CONFIG.AUDIO.SFX_VOLUME;
            this.muted = false;
        }
    }
    
    saveSettings() {
        try {
            const settings = {
                masterVolume: this.masterVolume,
                musicVolume: this.musicVolume,
                sfxVolume: this.sfxVolume,
                muted: this.muted,
            };
            localStorage.setItem(GAME_CONFIG.STORAGE.SETTINGS, JSON.stringify(settings));
        } catch (e) {
            console.warn('Could not save audio settings');
        }
    }
    
    /**
     * Initialize Web Audio context (must be called after user interaction)
     */
    init() {
        if (this.initialized) return;
        
        try {
            this.context = new (window.AudioContext || window.webkitAudioContext)();
            
            // Create gain nodes
            this.masterGain = this.context.createGain();
            this.musicGain = this.context.createGain();
            this.sfxGain = this.context.createGain();
            
            // Connect graph
            this.musicGain.connect(this.masterGain);
            this.sfxGain.connect(this.masterGain);
            this.masterGain.connect(this.context.destination);
            
            // Set volumes
            this.updateVolumes();
            
            this.initialized = true;
            console.log('Audio system initialized');
        } catch (e) {
            console.warn('Web Audio API not supported:', e);
        }
    }
    
    /**
     * Update gain node volumes
     */
    updateVolumes() {
        if (!this.initialized) return;
        
        const master = this.muted ? 0 : this.masterVolume;
        this.masterGain.gain.setValueAtTime(master, this.context.currentTime);
        this.musicGain.gain.setValueAtTime(this.musicVolume, this.context.currentTime);
        this.sfxGain.gain.setValueAtTime(this.sfxVolume, this.context.currentTime);
    }
    
    /**
     * Set master volume (0-1)
     */
    setMasterVolume(volume) {
        this.masterVolume = MathUtils.clamp(volume, 0, 1);
        this.updateVolumes();
        this.saveSettings();
    }
    
    /**
     * Set music volume (0-1)
     */
    setMusicVolume(volume) {
        this.musicVolume = MathUtils.clamp(volume, 0, 1);
        this.updateVolumes();
        this.saveSettings();
    }
    
    /**
     * Set SFX volume (0-1)
     */
    setSfxVolume(volume) {
        this.sfxVolume = MathUtils.clamp(volume, 0, 1);
        this.updateVolumes();
        this.saveSettings();
    }
    
    /**
     * Toggle mute
     */
    toggleMute() {
        this.muted = !this.muted;
        this.updateVolumes();
        this.saveSettings();
        return this.muted;
    }
    
    /**
     * Generate procedural sound effect
     */
    generateSFX(type) {
        if (!this.initialized) return null;
        
        const generators = {
            // Engine hum
            engine: () => this.createOscillatorSound(80, 'sawtooth', 0.1, 0.5),
            
            // Boost
            boost: () => {
                const osc = this.context.createOscillator();
                const gain = this.context.createGain();
                osc.type = 'sawtooth';
                osc.frequency.setValueAtTime(200, this.context.currentTime);
                osc.frequency.exponentialRampToValueAtTime(800, this.context.currentTime + 0.3);
                gain.gain.setValueAtTime(0.3, this.context.currentTime);
                gain.gain.exponentialRampToValueAtTime(0.01, this.context.currentTime + 0.5);
                osc.connect(gain);
                return { oscillator: osc, gain, duration: 0.5 };
            },
            
            // Collision
            hit: () => {
                const osc = this.context.createOscillator();
                const gain = this.context.createGain();
                osc.type = 'square';
                osc.frequency.setValueAtTime(150, this.context.currentTime);
                osc.frequency.exponentialRampToValueAtTime(50, this.context.currentTime + 0.2);
                gain.gain.setValueAtTime(0.4, this.context.currentTime);
                gain.gain.exponentialRampToValueAtTime(0.01, this.context.currentTime + 0.2);
                osc.connect(gain);
                return { oscillator: osc, gain, duration: 0.2 };
            },
            
            // Powerup collect
            powerup: () => {
                const osc = this.context.createOscillator();
                const gain = this.context.createGain();
                osc.type = 'sine';
                osc.frequency.setValueAtTime(400, this.context.currentTime);
                osc.frequency.exponentialRampToValueAtTime(800, this.context.currentTime + 0.1);
                osc.frequency.exponentialRampToValueAtTime(1200, this.context.currentTime + 0.2);
                gain.gain.setValueAtTime(0.2, this.context.currentTime);
                gain.gain.exponentialRampToValueAtTime(0.01, this.context.currentTime + 0.3);
                osc.connect(gain);
                return { oscillator: osc, gain, duration: 0.3 };
            },
            
            // Menu select
            select: () => this.createOscillatorSound(600, 'sine', 0.1, 0.15),
            
            // Menu hover
            hover: () => this.createOscillatorSound(400, 'sine', 0.05, 0.1),
            
            // Countdown beep
            beep: () => this.createOscillatorSound(800, 'sine', 0.2, 0.1),
            
            // Go!
            go: () => {
                const osc = this.context.createOscillator();
                const gain = this.context.createGain();
                osc.type = 'sine';
                osc.frequency.setValueAtTime(800, this.context.currentTime);
                osc.frequency.setValueAtTime(1000, this.context.currentTime + 0.1);
                osc.frequency.setValueAtTime(1200, this.context.currentTime + 0.2);
                gain.gain.setValueAtTime(0.3, this.context.currentTime);
                gain.gain.exponentialRampToValueAtTime(0.01, this.context.currentTime + 0.4);
                osc.connect(gain);
                return { oscillator: osc, gain, duration: 0.4 };
            },
            
            // Near miss whoosh
            whoosh: () => {
                const noise = this.createNoise();
                const gain = this.context.createGain();
                const filter = this.context.createBiquadFilter();
                filter.type = 'bandpass';
                filter.frequency.setValueAtTime(2000, this.context.currentTime);
                filter.frequency.exponentialRampToValueAtTime(500, this.context.currentTime + 0.2);
                filter.Q.value = 2;
                noise.connect(filter);
                filter.connect(gain);
                gain.gain.setValueAtTime(0.2, this.context.currentTime);
                gain.gain.exponentialRampToValueAtTime(0.01, this.context.currentTime + 0.2);
                return { source: noise, gain, duration: 0.2 };
            },
            
            // Checkpoint
            checkpoint: () => {
                const osc1 = this.context.createOscillator();
                const osc2 = this.context.createOscillator();
                const gain = this.context.createGain();
                osc1.type = 'sine';
                osc2.type = 'sine';
                osc1.frequency.value = 523.25; // C5
                osc2.frequency.value = 659.25; // E5
                osc1.connect(gain);
                osc2.connect(gain);
                gain.gain.setValueAtTime(0.15, this.context.currentTime);
                gain.gain.exponentialRampToValueAtTime(0.01, this.context.currentTime + 0.4);
                return { oscillators: [osc1, osc2], gain, duration: 0.4 };
            },
            
            // Game over
            gameover: () => {
                const osc = this.context.createOscillator();
                const gain = this.context.createGain();
                osc.type = 'sawtooth';
                osc.frequency.setValueAtTime(400, this.context.currentTime);
                osc.frequency.exponentialRampToValueAtTime(100, this.context.currentTime + 0.8);
                gain.gain.setValueAtTime(0.3, this.context.currentTime);
                gain.gain.exponentialRampToValueAtTime(0.01, this.context.currentTime + 1);
                osc.connect(gain);
                return { oscillator: osc, gain, duration: 1 };
            },
        };
        
        return generators[type] ? generators[type]() : null;
    }
    
    /**
     * Create simple oscillator sound
     */
    createOscillatorSound(frequency, type, volume, duration) {
        const osc = this.context.createOscillator();
        const gain = this.context.createGain();
        osc.type = type;
        osc.frequency.value = frequency;
        gain.gain.setValueAtTime(volume, this.context.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, this.context.currentTime + duration);
        osc.connect(gain);
        return { oscillator: osc, gain, duration };
    }
    
    /**
     * Create white noise source
     */
    createNoise() {
        const bufferSize = this.context.sampleRate * 0.5;
        const buffer = this.context.createBuffer(1, bufferSize, this.context.sampleRate);
        const data = buffer.getChannelData(0);
        for (let i = 0; i < bufferSize; i++) {
            data[i] = Math.random() * 2 - 1;
        }
        const source = this.context.createBufferSource();
        source.buffer = buffer;
        return source;
    }
    
    /**
     * Play a sound effect
     */
    playSFX(type) {
        if (!this.initialized || this.muted) return;
        
        const sound = this.generateSFX(type);
        if (!sound) return;
        
        sound.gain.connect(this.sfxGain);
        
        if (sound.oscillator) {
            sound.oscillator.start();
            sound.oscillator.stop(this.context.currentTime + sound.duration);
        } else if (sound.oscillators) {
            sound.oscillators.forEach(osc => {
                osc.start();
                osc.stop(this.context.currentTime + sound.duration);
            });
        } else if (sound.source) {
            sound.source.start();
            sound.source.stop(this.context.currentTime + sound.duration);
        }
    }
    
    /**
     * Generate and play background music
     */
    playMusic(key = 'main') {
        if (!this.initialized) return;
        if (this.currentMusicKey === key) return;
        
        this.stopMusic();
        this.currentMusicKey = key;
        
        // Create a procedural synth music loop
        this.musicLoop = this.createMusicLoop(key);
    }
    
    /**
     * Create procedural music loop
     */
    createMusicLoop(key) {
        const patterns = {
            menu: {
                tempo: 100,
                notes: [
                    { note: 'C4', duration: 2 },
                    { note: 'E4', duration: 1 },
                    { note: 'G4', duration: 1 },
                    { note: 'C5', duration: 2 },
                    { note: 'G4', duration: 1 },
                    { note: 'E4', duration: 1 },
                ],
            },
            game: {
                tempo: 140,
                notes: [
                    { note: 'E4', duration: 0.5 },
                    { note: 'E4', duration: 0.5 },
                    { note: 'G4', duration: 0.5 },
                    { note: 'E4', duration: 0.5 },
                    { note: 'D4', duration: 0.5 },
                    { note: 'E4', duration: 0.5 },
                    { note: 'A4', duration: 1 },
                    { note: 'G4', duration: 1 },
                ],
            },
            boss: {
                tempo: 160,
                notes: [
                    { note: 'E3', duration: 0.25 },
                    { note: 'E3', duration: 0.25 },
                    { note: 'E4', duration: 0.5 },
                    { note: 'E3', duration: 0.25 },
                    { note: 'E3', duration: 0.25 },
                    { note: 'D4', duration: 0.5 },
                    { note: 'E3', duration: 0.25 },
                    { note: 'E3', duration: 0.25 },
                    { note: 'C4', duration: 0.5 },
                    { note: 'B3', duration: 0.5 },
                ],
            },
        };
        
        // Music generation is complex - for now just create ambient drone
        const pattern = patterns[key] || patterns.menu;
        
        // Create a low drone
        const drone = this.context.createOscillator();
        const droneGain = this.context.createGain();
        drone.type = 'sine';
        drone.frequency.value = 55; // A1
        droneGain.gain.value = 0.1;
        drone.connect(droneGain);
        droneGain.connect(this.musicGain);
        drone.start();
        
        return { drone, droneGain };
    }
    
    /**
     * Stop music
     */
    stopMusic() {
        if (this.musicLoop) {
            if (this.musicLoop.drone) {
                this.musicLoop.drone.stop();
            }
            this.musicLoop = null;
        }
        this.currentMusicKey = null;
    }
    
    /**
     * Pause music
     */
    pauseMusic() {
        if (this.musicLoop && this.musicLoop.droneGain) {
            this.musicLoop.droneGain.gain.setValueAtTime(0, this.context.currentTime);
        }
    }
    
    /**
     * Resume music
     */
    resumeMusic() {
        if (this.musicLoop && this.musicLoop.droneGain) {
            this.musicLoop.droneGain.gain.setValueAtTime(0.1, this.context.currentTime);
        }
    }
    
    /**
     * Cleanup
     */
    destroy() {
        this.stopMusic();
        if (this.context) {
            this.context.close();
        }
    }
}

// Note frequencies
const NOTE_FREQUENCIES = {
    'C3': 130.81, 'D3': 146.83, 'E3': 164.81, 'F3': 174.61, 'G3': 196.00, 'A3': 220.00, 'B3': 246.94,
    'C4': 261.63, 'D4': 293.66, 'E4': 329.63, 'F4': 349.23, 'G4': 392.00, 'A4': 440.00, 'B4': 493.88,
    'C5': 523.25, 'D5': 587.33, 'E5': 659.25, 'F5': 698.46, 'G5': 783.99, 'A5': 880.00, 'B5': 987.77,
};

// Export
if (typeof window !== 'undefined') {
    window.AudioManager = AudioManager;
    window.NOTE_FREQUENCIES = NOTE_FREQUENCIES;
}
