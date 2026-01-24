/**
 * NEON TRAIL - Audio Manager
 * Handles all sound effects and music with procedural audio generation
 */

class AudioManager {
    constructor(scene) {
        this.scene = scene;
        
        // Audio context for procedural sounds
        this.audioContext = null;
        this.masterGain = null;
        
        // Volume settings
        this.masterVolume = AUDIO_CONFIG.MASTER;
        this.musicVolume = AUDIO_CONFIG.MUSIC;
        this.sfxVolume = AUDIO_CONFIG.SFX;
        
        // Currently playing
        this.currentMusic = null;
        this.activeSounds = new Map();
        
        // Mute state
        this.isMuted = false;
        
        // Engine sound oscillator
        this.engineOscillator = null;
        this.engineGain = null;
        this.engineFrequency = 80;
    }
    
    /**
     * Initialize audio system
     */
    create() {
        try {
            // Create Web Audio context
            const AudioContext = window.AudioContext || window.webkitAudioContext;
            this.audioContext = new AudioContext();
            
            // Master gain
            this.masterGain = this.audioContext.createGain();
            this.masterGain.gain.value = this.masterVolume;
            this.masterGain.connect(this.audioContext.destination);
            
            // Resume context on user interaction (browser requirement)
            const resumeAudio = () => {
                if (this.audioContext && this.audioContext.state === 'suspended') {
                    this.audioContext.resume();
                }
            };
            
            document.addEventListener('click', resumeAudio, { once: true });
            document.addEventListener('keydown', resumeAudio, { once: true });
            document.addEventListener('touchstart', resumeAudio, { once: true });
            
        } catch (e) {
            console.warn('Web Audio not supported:', e);
        }
        
        return this;
    }
    
    /**
     * Play a procedural sound effect
     */
    playSFX(type, options = {}) {
        if (this.isMuted || !this.audioContext) return;
        
        switch (type) {
            case 'menu_select':
                this.playBeep(880, 0.1, 'sine');
                break;
            case 'menu_hover':
                this.playBeep(440, 0.05, 'sine');
                break;
            case 'collision':
                this.playNoise(0.3, 0.1);
                this.playBeep(100, 0.2, 'sawtooth');
                break;
            case 'powerup':
                this.playPowerUpSound(options.color);
                break;
            case 'drift':
                this.playDriftSound();
                break;
            case 'near_miss':
                this.playBeep(1200, 0.1, 'sine');
                this.playBeep(1400, 0.1, 'sine', 0.05);
                break;
            case 'countdown':
                this.playBeep(440, 0.2, 'square');
                break;
            case 'countdown_go':
                this.playBeep(880, 0.3, 'square');
                break;
            case 'game_over':
                this.playGameOverSound();
                break;
            case 'milestone':
                this.playMilestoneSound();
                break;
            case 'highscore':
                this.playHighscoreSound();
                break;
        }
    }
    
    /**
     * Play a simple beep
     */
    playBeep(frequency, duration, waveform = 'sine', delay = 0) {
        if (!this.audioContext) return;
        
        const oscillator = this.audioContext.createOscillator();
        const gainNode = this.audioContext.createGain();
        
        oscillator.type = waveform;
        oscillator.frequency.value = frequency;
        
        gainNode.gain.value = this.sfxVolume * 0.3;
        
        oscillator.connect(gainNode);
        gainNode.connect(this.masterGain);
        
        const startTime = this.audioContext.currentTime + delay;
        oscillator.start(startTime);
        
        // Envelope
        gainNode.gain.setValueAtTime(this.sfxVolume * 0.3, startTime);
        gainNode.gain.exponentialRampToValueAtTime(0.001, startTime + duration);
        
        oscillator.stop(startTime + duration);
    }
    
    /**
     * Play noise burst
     */
    playNoise(duration, volume) {
        if (!this.audioContext) return;
        
        const bufferSize = this.audioContext.sampleRate * duration;
        const buffer = this.audioContext.createBuffer(1, bufferSize, this.audioContext.sampleRate);
        const data = buffer.getChannelData(0);
        
        for (let i = 0; i < bufferSize; i++) {
            data[i] = (Math.random() * 2 - 1) * volume;
        }
        
        const source = this.audioContext.createBufferSource();
        source.buffer = buffer;
        
        const gainNode = this.audioContext.createGain();
        gainNode.gain.value = this.sfxVolume;
        
        source.connect(gainNode);
        gainNode.connect(this.masterGain);
        
        source.start();
        
        // Fade out
        gainNode.gain.exponentialRampToValueAtTime(0.001, this.audioContext.currentTime + duration);
    }
    
    /**
     * Play power-up collection sound
     */
    playPowerUpSound(color) {
        if (!this.audioContext) return;
        
        // Ascending arpeggio
        const frequencies = [523, 659, 784, 1047]; // C5, E5, G5, C6
        
        frequencies.forEach((freq, i) => {
            this.playBeep(freq, 0.1, 'sine', i * 0.05);
        });
    }
    
    /**
     * Play drift sound
     */
    playDriftSound() {
        if (!this.audioContext) return;
        
        // Tire screech (filtered noise)
        const bufferSize = this.audioContext.sampleRate * 0.2;
        const buffer = this.audioContext.createBuffer(1, bufferSize, this.audioContext.sampleRate);
        const data = buffer.getChannelData(0);
        
        for (let i = 0; i < bufferSize; i++) {
            data[i] = (Math.random() * 2 - 1) * 0.3;
        }
        
        const source = this.audioContext.createBufferSource();
        source.buffer = buffer;
        
        // High-pass filter for screech
        const filter = this.audioContext.createBiquadFilter();
        filter.type = 'highpass';
        filter.frequency.value = 2000;
        
        const gainNode = this.audioContext.createGain();
        gainNode.gain.value = this.sfxVolume * 0.2;
        
        source.connect(filter);
        filter.connect(gainNode);
        gainNode.connect(this.masterGain);
        
        source.start();
        
        gainNode.gain.exponentialRampToValueAtTime(0.001, this.audioContext.currentTime + 0.2);
    }
    
    /**
     * Play game over sound
     */
    playGameOverSound() {
        if (!this.audioContext) return;
        
        // Descending notes
        const frequencies = [440, 392, 349, 330, 294, 262];
        
        frequencies.forEach((freq, i) => {
            this.playBeep(freq, 0.2, 'sawtooth', i * 0.1);
        });
        
        // Explosion noise
        this.playNoise(0.5, 0.3);
    }
    
    /**
     * Play milestone sound
     */
    playMilestoneSound() {
        if (!this.audioContext) return;
        
        // Triumphant chord
        const chord = [523, 659, 784]; // C major
        
        chord.forEach(freq => {
            this.playBeep(freq, 0.3, 'sine');
        });
        
        // Octave up
        setTimeout(() => {
            chord.forEach(freq => {
                this.playBeep(freq * 2, 0.4, 'sine');
            });
        }, 200);
    }
    
    /**
     * Play highscore sound
     */
    playHighscoreSound() {
        if (!this.audioContext) return;
        
        // Fanfare
        const notes = [523, 659, 784, 1047, 784, 1047];
        const durations = [0.1, 0.1, 0.1, 0.3, 0.1, 0.4];
        
        let time = 0;
        notes.forEach((freq, i) => {
            this.playBeep(freq, durations[i], 'square', time);
            time += durations[i];
        });
    }
    
    /**
     * Start engine sound
     */
    startEngine() {
        if (!this.audioContext || this.engineOscillator) return;
        
        this.engineOscillator = this.audioContext.createOscillator();
        this.engineGain = this.audioContext.createGain();
        
        this.engineOscillator.type = 'sawtooth';
        this.engineOscillator.frequency.value = this.engineFrequency;
        
        // Low volume for background hum
        this.engineGain.gain.value = this.isMuted ? 0 : this.sfxVolume * 0.05;
        
        // Low-pass filter for muffled engine sound
        const filter = this.audioContext.createBiquadFilter();
        filter.type = 'lowpass';
        filter.frequency.value = 200;
        
        this.engineOscillator.connect(filter);
        filter.connect(this.engineGain);
        this.engineGain.connect(this.masterGain);
        
        this.engineOscillator.start();
    }
    
    /**
     * Update engine sound based on speed
     */
    updateEngine(speed, maxSpeed) {
        if (!this.engineOscillator) return;
        
        // Map speed to frequency (80-200 Hz)
        const normalizedSpeed = Math.min(speed / maxSpeed, 1);
        this.engineFrequency = 80 + normalizedSpeed * 120;
        
        this.engineOscillator.frequency.setTargetAtTime(
            this.engineFrequency,
            this.audioContext.currentTime,
            0.1
        );
        
        // Also increase volume slightly with speed
        if (this.engineGain && !this.isMuted) {
            const volume = this.sfxVolume * (0.03 + normalizedSpeed * 0.04);
            this.engineGain.gain.setTargetAtTime(volume, this.audioContext.currentTime, 0.1);
        }
    }
    
    /**
     * Stop engine sound
     */
    stopEngine() {
        if (this.engineOscillator) {
            this.engineOscillator.stop();
            this.engineOscillator.disconnect();
            this.engineOscillator = null;
        }
        if (this.engineGain) {
            this.engineGain.disconnect();
            this.engineGain = null;
        }
    }
    
    /**
     * Set master volume
     */
    setMasterVolume(volume) {
        this.masterVolume = Math.max(0, Math.min(1, volume));
        if (this.masterGain) {
            this.masterGain.gain.value = this.masterVolume;
        }
    }
    
    /**
     * Set SFX volume
     */
    setSFXVolume(volume) {
        this.sfxVolume = Math.max(0, Math.min(1, volume));
    }
    
    /**
     * Set music volume
     */
    setMusicVolume(volume) {
        this.musicVolume = Math.max(0, Math.min(1, volume));
    }
    
    /**
     * Toggle mute
     */
    toggleMute() {
        this.isMuted = !this.isMuted;
        
        if (this.masterGain) {
            this.masterGain.gain.value = this.isMuted ? 0 : this.masterVolume;
        }
        
        if (this.engineGain) {
            this.engineGain.gain.value = this.isMuted ? 0 : this.sfxVolume * 0.05;
        }
        
        return this.isMuted;
    }
    
    /**
     * Cleanup
     */
    destroy() {
        this.stopEngine();
        
        if (this.audioContext) {
            this.audioContext.close();
            this.audioContext = null;
        }
        
        this.activeSounds.clear();
    }
}
