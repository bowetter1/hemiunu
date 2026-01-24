/**
 * WeatherSystem.js
 * Dynamic weather effects system for visual variety
 * Includes rain, snow, fog, storm, and aurora effects
 */

class WeatherSystem {
    constructor(scene) {
        this.scene = scene;
        
        // Current weather state
        this.currentWeather = 'clear';
        this.intensity = 1.0;
        this.transitionProgress = 1.0;
        this.isTransitioning = false;
        
        // Graphics layers
        this.backgroundLayer = null;
        this.particleLayer = null;
        this.overlayLayer = null;
        this.lightningLayer = null;
        
        // Particle pools
        this.raindrops = [];
        this.snowflakes = [];
        this.fogPatches = [];
        this.dustParticles = [];
        this.auroraWaves = [];
        
        // Configuration
        this.config = this.defineWeatherConfig();
        
        // Audio references
        this.weatherSounds = {};
        
        // Performance settings
        this.maxParticles = 500;
        this.updateInterval = 16; // ~60fps
        this.lastUpdate = 0;
    }
    
    /**
     * Define weather configurations
     */
    defineWeatherConfig() {
        return {
            clear: {
                name: 'Clear',
                particles: 0,
                visibility: 1.0,
                ambient: { r: 255, g: 255, b: 255 },
                overlay: null,
                sound: null,
                effects: []
            },
            
            rain: {
                name: 'Rain',
                particles: 200,
                visibility: 0.8,
                ambient: { r: 180, g: 190, b: 210 },
                overlay: { color: 0x1a2535, alpha: 0.2 },
                sound: 'rain',
                effects: ['rain', 'ripples', 'mist'],
                particleConfig: {
                    speedY: { min: 800, max: 1200 },
                    speedX: { min: -50, max: 50 },
                    length: { min: 10, max: 25 },
                    color: 0x88aacc,
                    alpha: { min: 0.3, max: 0.6 }
                }
            },
            
            heavy_rain: {
                name: 'Heavy Rain',
                particles: 400,
                visibility: 0.5,
                ambient: { r: 150, g: 160, b: 180 },
                overlay: { color: 0x0a1525, alpha: 0.4 },
                sound: 'heavy_rain',
                effects: ['rain', 'ripples', 'mist', 'lightning'],
                particleConfig: {
                    speedY: { min: 1000, max: 1500 },
                    speedX: { min: -100, max: 100 },
                    length: { min: 15, max: 35 },
                    color: 0x6688aa,
                    alpha: { min: 0.4, max: 0.7 }
                }
            },
            
            snow: {
                name: 'Snow',
                particles: 150,
                visibility: 0.7,
                ambient: { r: 220, g: 230, b: 255 },
                overlay: { color: 0xaabbcc, alpha: 0.1 },
                sound: 'wind_light',
                effects: ['snow', 'frost'],
                particleConfig: {
                    speedY: { min: 50, max: 150 },
                    speedX: { min: -30, max: 30 },
                    size: { min: 2, max: 6 },
                    color: 0xffffff,
                    alpha: { min: 0.6, max: 0.9 },
                    wobble: true
                }
            },
            
            blizzard: {
                name: 'Blizzard',
                particles: 350,
                visibility: 0.3,
                ambient: { r: 200, g: 210, b: 230 },
                overlay: { color: 0xcceeff, alpha: 0.3 },
                sound: 'wind_strong',
                effects: ['snow', 'frost', 'wind_streaks'],
                particleConfig: {
                    speedY: { min: 100, max: 200 },
                    speedX: { min: 200, max: 400 },
                    size: { min: 2, max: 8 },
                    color: 0xffffff,
                    alpha: { min: 0.5, max: 0.8 },
                    wobble: true
                }
            },
            
            fog: {
                name: 'Fog',
                particles: 30,
                visibility: 0.4,
                ambient: { r: 200, g: 200, b: 210 },
                overlay: { color: 0xaabbcc, alpha: 0.4 },
                sound: null,
                effects: ['fog_patches'],
                particleConfig: {
                    size: { min: 100, max: 250 },
                    speedX: { min: 10, max: 40 },
                    alpha: { min: 0.2, max: 0.5 }
                }
            },
            
            sandstorm: {
                name: 'Sandstorm',
                particles: 300,
                visibility: 0.4,
                ambient: { r: 220, g: 180, b: 130 },
                overlay: { color: 0xccaa77, alpha: 0.3 },
                sound: 'wind_strong',
                effects: ['dust', 'wind_streaks'],
                particleConfig: {
                    speedY: { min: -30, max: 30 },
                    speedX: { min: 300, max: 600 },
                    size: { min: 1, max: 4 },
                    color: 0xddbb88,
                    alpha: { min: 0.4, max: 0.7 }
                }
            },
            
            aurora: {
                name: 'Aurora',
                particles: 10,
                visibility: 1.0,
                ambient: { r: 200, g: 255, b: 230 },
                overlay: null,
                sound: 'ambient_space',
                effects: ['aurora_waves', 'stars'],
                particleConfig: {
                    colors: [0x00ff88, 0x00ffff, 0x8844ff, 0xff44aa],
                    waveSpeed: 0.5,
                    waveHeight: 50
                }
            },
            
            storm: {
                name: 'Storm',
                particles: 250,
                visibility: 0.6,
                ambient: { r: 160, g: 170, b: 190 },
                overlay: { color: 0x1a2535, alpha: 0.3 },
                sound: 'storm',
                effects: ['rain', 'lightning', 'wind_streaks'],
                particleConfig: {
                    speedY: { min: 900, max: 1300 },
                    speedX: { min: 50, max: 150 },
                    length: { min: 12, max: 30 },
                    color: 0x7799bb,
                    alpha: { min: 0.4, max: 0.6 }
                }
            },
            
            cosmic: {
                name: 'Cosmic',
                particles: 100,
                visibility: 1.0,
                ambient: { r: 180, g: 200, b: 255 },
                overlay: null,
                sound: 'ambient_space',
                effects: ['stars', 'shooting_stars', 'nebula'],
                particleConfig: {
                    colors: [0x00ffff, 0xff00ff, 0xffff00, 0x00ff00],
                    twinkle: true
                }
            }
        };
    }
    
    /**
     * Initialize weather system
     */
    initialize() {
        const { width, height } = this.scene.cameras.main;
        
        // Create graphics layers
        this.backgroundLayer = this.scene.add.graphics();
        this.backgroundLayer.setDepth(5);
        
        this.particleLayer = this.scene.add.graphics();
        this.particleLayer.setDepth(100);
        
        this.overlayLayer = this.scene.add.graphics();
        this.overlayLayer.setDepth(800);
        
        this.lightningLayer = this.scene.add.graphics();
        this.lightningLayer.setDepth(850);
        
        // Initialize particle pools
        this.initializeParticlePools();
    }
    
    /**
     * Initialize particle pools
     */
    initializeParticlePools() {
        // Rain pool
        for (let i = 0; i < this.maxParticles; i++) {
            this.raindrops.push({
                x: 0, y: 0, vx: 0, vy: 0,
                length: 10, alpha: 0.5,
                active: false
            });
        }
        
        // Snow pool
        for (let i = 0; i < this.maxParticles; i++) {
            this.snowflakes.push({
                x: 0, y: 0, vx: 0, vy: 0,
                size: 3, alpha: 0.7,
                wobbleOffset: Math.random() * Math.PI * 2,
                active: false
            });
        }
        
        // Fog pool
        for (let i = 0; i < 50; i++) {
            this.fogPatches.push({
                x: 0, y: 0, vx: 0,
                size: 150, alpha: 0.3,
                active: false
            });
        }
        
        // Dust pool
        for (let i = 0; i < this.maxParticles; i++) {
            this.dustParticles.push({
                x: 0, y: 0, vx: 0, vy: 0,
                size: 2, alpha: 0.5,
                active: false
            });
        }
        
        // Aurora waves
        for (let i = 0; i < 20; i++) {
            this.auroraWaves.push({
                offset: i * 50,
                amplitude: 30 + Math.random() * 40,
                speed: 0.3 + Math.random() * 0.4,
                color: 0x00ff88,
                alpha: 0.3,
                active: false
            });
        }
    }
    
    /**
     * Set weather type
     */
    setWeather(weatherType, immediate = false) {
        if (!this.config[weatherType]) {
            console.warn(`Unknown weather type: ${weatherType}`);
            return;
        }
        
        if (weatherType === this.currentWeather) return;
        
        if (immediate) {
            this.applyWeatherImmediate(weatherType);
        } else {
            this.startWeatherTransition(weatherType);
        }
    }
    
    /**
     * Apply weather immediately without transition
     */
    applyWeatherImmediate(weatherType) {
        const oldWeather = this.currentWeather;
        this.currentWeather = weatherType;
        this.transitionProgress = 1.0;
        this.isTransitioning = false;
        
        // Reset particles
        this.resetParticles();
        
        // Apply new weather particles
        const config = this.config[weatherType];
        this.spawnInitialParticles(config);
        
        // Update sounds
        this.updateWeatherSound(oldWeather, weatherType);
    }
    
    /**
     * Start weather transition
     */
    startWeatherTransition(targetWeather) {
        this.targetWeather = targetWeather;
        this.isTransitioning = true;
        this.transitionProgress = 0;
        
        // Tween the transition
        this.scene.tweens.add({
            targets: this,
            transitionProgress: 1,
            duration: 3000,
            ease: 'Power2',
            onUpdate: () => {
                this.updateTransition();
            },
            onComplete: () => {
                this.completeTransition();
            }
        });
    }
    
    /**
     * Update during transition
     */
    updateTransition() {
        // Blend particle counts
        const currentConfig = this.config[this.currentWeather];
        const targetConfig = this.config[this.targetWeather];
        
        const blendedCount = Math.floor(
            currentConfig.particles * (1 - this.transitionProgress) +
            targetConfig.particles * this.transitionProgress
        );
        
        // Update overlay blend
        this.updateOverlayBlend();
    }
    
    /**
     * Complete weather transition
     */
    completeTransition() {
        const oldWeather = this.currentWeather;
        this.currentWeather = this.targetWeather;
        this.isTransitioning = false;
        this.targetWeather = null;
        
        // Update sounds
        this.updateWeatherSound(oldWeather, this.currentWeather);
    }
    
    /**
     * Reset all particles
     */
    resetParticles() {
        this.raindrops.forEach(p => p.active = false);
        this.snowflakes.forEach(p => p.active = false);
        this.fogPatches.forEach(p => p.active = false);
        this.dustParticles.forEach(p => p.active = false);
        this.auroraWaves.forEach(p => p.active = false);
    }
    
    /**
     * Spawn initial particles for weather type
     */
    spawnInitialParticles(config) {
        const { width, height } = this.scene.cameras.main;
        const effects = config.effects || [];
        
        effects.forEach(effect => {
            switch (effect) {
                case 'rain':
                    this.spawnRainParticles(config, width, height);
                    break;
                case 'snow':
                    this.spawnSnowParticles(config, width, height);
                    break;
                case 'fog_patches':
                    this.spawnFogPatches(config, width, height);
                    break;
                case 'dust':
                    this.spawnDustParticles(config, width, height);
                    break;
                case 'aurora_waves':
                    this.spawnAuroraWaves(config, width, height);
                    break;
            }
        });
    }
    
    /**
     * Spawn rain particles
     */
    spawnRainParticles(config, width, height) {
        const pConfig = config.particleConfig;
        const count = Math.min(config.particles, this.maxParticles);
        
        for (let i = 0; i < count; i++) {
            const drop = this.raindrops[i];
            drop.active = true;
            drop.x = Math.random() * width;
            drop.y = Math.random() * height;
            drop.vx = this.randomRange(pConfig.speedX.min, pConfig.speedX.max);
            drop.vy = this.randomRange(pConfig.speedY.min, pConfig.speedY.max);
            drop.length = this.randomRange(pConfig.length.min, pConfig.length.max);
            drop.alpha = this.randomRange(pConfig.alpha.min, pConfig.alpha.max);
            drop.color = pConfig.color;
        }
    }
    
    /**
     * Spawn snow particles
     */
    spawnSnowParticles(config, width, height) {
        const pConfig = config.particleConfig;
        const count = Math.min(config.particles, this.maxParticles);
        
        for (let i = 0; i < count; i++) {
            const flake = this.snowflakes[i];
            flake.active = true;
            flake.x = Math.random() * width;
            flake.y = Math.random() * height;
            flake.vx = this.randomRange(pConfig.speedX.min, pConfig.speedX.max);
            flake.vy = this.randomRange(pConfig.speedY.min, pConfig.speedY.max);
            flake.size = this.randomRange(pConfig.size.min, pConfig.size.max);
            flake.alpha = this.randomRange(pConfig.alpha.min, pConfig.alpha.max);
            flake.wobbleOffset = Math.random() * Math.PI * 2;
        }
    }
    
    /**
     * Spawn fog patches
     */
    spawnFogPatches(config, width, height) {
        const pConfig = config.particleConfig;
        const count = Math.min(config.particles, 50);
        
        for (let i = 0; i < count; i++) {
            const fog = this.fogPatches[i];
            fog.active = true;
            fog.x = Math.random() * (width + 200) - 100;
            fog.y = Math.random() * height;
            fog.vx = this.randomRange(pConfig.speedX.min, pConfig.speedX.max);
            fog.size = this.randomRange(pConfig.size.min, pConfig.size.max);
            fog.alpha = this.randomRange(pConfig.alpha.min, pConfig.alpha.max);
        }
    }
    
    /**
     * Spawn dust particles
     */
    spawnDustParticles(config, width, height) {
        const pConfig = config.particleConfig;
        const count = Math.min(config.particles, this.maxParticles);
        
        for (let i = 0; i < count; i++) {
            const dust = this.dustParticles[i];
            dust.active = true;
            dust.x = Math.random() * width;
            dust.y = Math.random() * height;
            dust.vx = this.randomRange(pConfig.speedX.min, pConfig.speedX.max);
            dust.vy = this.randomRange(pConfig.speedY.min, pConfig.speedY.max);
            dust.size = this.randomRange(pConfig.size.min, pConfig.size.max);
            dust.alpha = this.randomRange(pConfig.alpha.min, pConfig.alpha.max);
            dust.color = pConfig.color;
        }
    }
    
    /**
     * Spawn aurora waves
     */
    spawnAuroraWaves(config, width, height) {
        const pConfig = config.particleConfig;
        const colors = pConfig.colors;
        
        for (let i = 0; i < this.auroraWaves.length; i++) {
            const wave = this.auroraWaves[i];
            wave.active = true;
            wave.offset = i * (width / this.auroraWaves.length);
            wave.amplitude = 30 + Math.random() * 40;
            wave.speed = pConfig.waveSpeed + Math.random() * 0.3;
            wave.color = colors[i % colors.length];
            wave.alpha = 0.2 + Math.random() * 0.2;
            wave.phase = Math.random() * Math.PI * 2;
        }
    }
    
    /**
     * Update weather system
     */
    update(time, delta) {
        if (time - this.lastUpdate < this.updateInterval) return;
        this.lastUpdate = time;
        
        const { width, height } = this.scene.cameras.main;
        const config = this.config[this.currentWeather];
        const effects = config.effects || [];
        
        // Clear graphics
        this.particleLayer.clear();
        this.overlayLayer.clear();
        this.lightningLayer.clear();
        
        // Update and render particles
        effects.forEach(effect => {
            switch (effect) {
                case 'rain':
                    this.updateRain(delta, width, height);
                    break;
                case 'snow':
                    this.updateSnow(delta, time, width, height);
                    break;
                case 'fog_patches':
                    this.updateFog(delta, width, height);
                    break;
                case 'dust':
                    this.updateDust(delta, width, height);
                    break;
                case 'aurora_waves':
                    this.updateAurora(time, width, height);
                    break;
                case 'lightning':
                    this.updateLightning(time, width, height);
                    break;
                case 'ripples':
                    this.updateRipples(time, width, height);
                    break;
            }
        });
        
        // Render overlay
        if (config.overlay) {
            this.renderOverlay(config.overlay, width, height);
        }
    }
    
    /**
     * Update rain particles
     */
    updateRain(delta, width, height) {
        const dt = delta / 1000;
        const config = this.config[this.currentWeather].particleConfig;
        
        this.raindrops.forEach(drop => {
            if (!drop.active) return;
            
            // Update position
            drop.x += drop.vx * dt;
            drop.y += drop.vy * dt;
            
            // Wrap around screen
            if (drop.y > height + 20) {
                drop.y = -drop.length;
                drop.x = Math.random() * width;
            }
            if (drop.x < -20) drop.x = width + 20;
            if (drop.x > width + 20) drop.x = -20;
            
            // Render
            this.particleLayer.lineStyle(1, drop.color, drop.alpha * this.intensity);
            this.particleLayer.lineBetween(
                drop.x, drop.y,
                drop.x + drop.vx * 0.02, drop.y + drop.length
            );
        });
    }
    
    /**
     * Update snow particles
     */
    updateSnow(delta, time, width, height) {
        const dt = delta / 1000;
        
        this.snowflakes.forEach(flake => {
            if (!flake.active) return;
            
            // Update position with wobble
            const wobble = Math.sin(time * 0.002 + flake.wobbleOffset) * 30;
            flake.x += (flake.vx + wobble * dt) * dt;
            flake.y += flake.vy * dt;
            
            // Wrap around screen
            if (flake.y > height + 10) {
                flake.y = -10;
                flake.x = Math.random() * width;
            }
            if (flake.x < -20) flake.x = width + 20;
            if (flake.x > width + 20) flake.x = -20;
            
            // Render
            this.particleLayer.fillStyle(0xffffff, flake.alpha * this.intensity);
            this.particleLayer.fillCircle(flake.x, flake.y, flake.size);
        });
    }
    
    /**
     * Update fog patches
     */
    updateFog(delta, width, height) {
        const dt = delta / 1000;
        
        this.fogPatches.forEach(fog => {
            if (!fog.active) return;
            
            // Update position
            fog.x += fog.vx * dt;
            
            // Wrap around
            if (fog.x > width + fog.size) {
                fog.x = -fog.size;
                fog.y = Math.random() * height;
            }
            
            // Render fog patch (simple radial gradient simulation)
            const gradient = this.particleLayer;
            for (let r = fog.size; r > 0; r -= fog.size / 10) {
                const alpha = fog.alpha * (1 - r / fog.size) * 0.3 * this.intensity;
                gradient.fillStyle(0xaabbcc, alpha);
                gradient.fillCircle(fog.x, fog.y, r);
            }
        });
    }
    
    /**
     * Update dust particles
     */
    updateDust(delta, width, height) {
        const dt = delta / 1000;
        
        this.dustParticles.forEach(dust => {
            if (!dust.active) return;
            
            // Update position
            dust.x += dust.vx * dt;
            dust.y += dust.vy * dt;
            
            // Wrap around
            if (dust.x > width + 10) {
                dust.x = -10;
                dust.y = Math.random() * height;
            }
            if (dust.y < -10) dust.y = height + 10;
            if (dust.y > height + 10) dust.y = -10;
            
            // Render
            this.particleLayer.fillStyle(dust.color, dust.alpha * this.intensity);
            this.particleLayer.fillCircle(dust.x, dust.y, dust.size);
        });
    }
    
    /**
     * Update aurora effect
     */
    updateAurora(time, width, height) {
        const t = time * 0.001;
        
        this.auroraWaves.forEach((wave, index) => {
            if (!wave.active) return;
            
            // Draw wavy aurora band
            this.particleLayer.lineStyle(40, wave.color, wave.alpha * this.intensity);
            
            this.particleLayer.beginPath();
            
            for (let x = 0; x <= width; x += 10) {
                const waveY = height * 0.2 + 
                    Math.sin((x + wave.offset) * 0.01 + t * wave.speed + wave.phase) * wave.amplitude +
                    Math.sin((x + wave.offset) * 0.02 + t * wave.speed * 1.5) * wave.amplitude * 0.5;
                
                if (x === 0) {
                    this.particleLayer.moveTo(x, waveY);
                } else {
                    this.particleLayer.lineTo(x, waveY);
                }
            }
            
            this.particleLayer.strokePath();
        });
    }
    
    /**
     * Update lightning effect
     */
    updateLightning(time, width, height) {
        // Random lightning strikes
        if (Math.random() > 0.998) {
            this.createLightningStrike(width, height);
        }
    }
    
    /**
     * Create a lightning strike
     */
    createLightningStrike(width, height) {
        const startX = Math.random() * width;
        const startY = 0;
        
        // Flash effect
        this.lightningLayer.fillStyle(0xffffff, 0.3);
        this.lightningLayer.fillRect(0, 0, width, height);
        
        // Lightning bolt
        this.lightningLayer.lineStyle(3, 0xaaccff, 1);
        this.lightningLayer.beginPath();
        this.lightningLayer.moveTo(startX, startY);
        
        let x = startX;
        let y = startY;
        
        while (y < height) {
            x += (Math.random() - 0.5) * 100;
            y += 20 + Math.random() * 40;
            this.lightningLayer.lineTo(x, y);
            
            // Branching
            if (Math.random() > 0.7 && y < height * 0.7) {
                const branchX = x;
                const branchY = y;
                let bx = branchX;
                let by = branchY;
                
                this.lightningLayer.moveTo(branchX, branchY);
                for (let i = 0; i < 3; i++) {
                    bx += (Math.random() - 0.5) * 80 + (Math.random() > 0.5 ? 30 : -30);
                    by += 15 + Math.random() * 25;
                    this.lightningLayer.lineTo(bx, by);
                }
                this.lightningLayer.moveTo(x, y);
            }
        }
        
        this.lightningLayer.strokePath();
        
        // Play thunder sound
        if (window.SoundManager) {
            this.scene.time.delayedCall(100 + Math.random() * 500, () => {
                SoundManager.play('thunder');
            });
        }
        
        // Fade out lightning
        this.scene.tweens.add({
            targets: { alpha: 1 },
            alpha: 0,
            duration: 200,
            onUpdate: (tween) => {
                this.lightningLayer.setAlpha(tween.getValue());
            },
            onComplete: () => {
                this.lightningLayer.setAlpha(1);
                this.lightningLayer.clear();
            }
        });
    }
    
    /**
     * Update ripple effects
     */
    updateRipples(time, width, height) {
        // Ground ripples for rain
        if (this.currentWeather.includes('rain')) {
            for (let i = 0; i < 5; i++) {
                if (Math.random() > 0.7) {
                    const x = Math.random() * width;
                    const y = height - 50 + Math.random() * 50;
                    const size = 5 + Math.random() * 10;
                    
                    this.particleLayer.lineStyle(1, 0x88aacc, 0.3);
                    this.particleLayer.strokeCircle(x, y, size);
                }
            }
        }
    }
    
    /**
     * Render weather overlay
     */
    renderOverlay(overlay, width, height) {
        this.overlayLayer.fillStyle(overlay.color, overlay.alpha * this.intensity);
        this.overlayLayer.fillRect(0, 0, width, height);
    }
    
    /**
     * Update overlay blend during transition
     */
    updateOverlayBlend() {
        if (!this.isTransitioning) return;
        
        const currentConfig = this.config[this.currentWeather];
        const targetConfig = this.config[this.targetWeather];
        
        // Blend overlays
        // Implementation depends on specific blending needs
    }
    
    /**
     * Update weather sound
     */
    updateWeatherSound(oldWeather, newWeather) {
        const oldConfig = this.config[oldWeather];
        const newConfig = this.config[newWeather];
        
        // Stop old weather sound
        if (oldConfig.sound && this.weatherSounds[oldConfig.sound]) {
            // Fade out old sound
            if (window.SoundManager) {
                SoundManager.fadeOut(oldConfig.sound, 1000);
            }
        }
        
        // Start new weather sound
        if (newConfig.sound) {
            if (window.SoundManager) {
                SoundManager.playLoop(newConfig.sound, { fadeIn: 1000 });
            }
        }
    }
    
    /**
     * Set weather intensity
     */
    setIntensity(intensity) {
        this.intensity = Phaser.Math.Clamp(intensity, 0, 1);
    }
    
    /**
     * Get visibility modifier
     */
    getVisibility() {
        const config = this.config[this.currentWeather];
        return config.visibility * this.intensity + (1 - this.intensity);
    }
    
    /**
     * Get ambient color
     */
    getAmbientColor() {
        const config = this.config[this.currentWeather];
        return config.ambient;
    }
    
    /**
     * Random number in range
     */
    randomRange(min, max) {
        return min + Math.random() * (max - min);
    }
    
    /**
     * Clean up weather system
     */
    destroy() {
        // Stop all sounds
        Object.keys(this.weatherSounds).forEach(sound => {
            if (window.SoundManager) {
                SoundManager.stop(sound);
            }
        });
        
        // Destroy graphics
        if (this.backgroundLayer) this.backgroundLayer.destroy();
        if (this.particleLayer) this.particleLayer.destroy();
        if (this.overlayLayer) this.overlayLayer.destroy();
        if (this.lightningLayer) this.lightningLayer.destroy();
    }
}

// Export
if (typeof window !== 'undefined') {
    window.WeatherSystem = WeatherSystem;
}
