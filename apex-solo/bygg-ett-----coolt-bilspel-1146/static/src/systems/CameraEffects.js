/**
 * CameraEffects.js
 * Advanced camera effects and transitions
 * Screen shake, zoom, flash, fade, and cinematic effects
 */

class CameraEffects {
    constructor(scene) {
        this.scene = scene;
        this.camera = scene.cameras.main;
        
        // Effect states
        this.shakeIntensity = 0;
        this.shakeDecay = 0.9;
        this.isShaking = false;
        
        this.zoomTarget = 1;
        this.zoomSpeed = 0.1;
        
        this.flashAlpha = 0;
        this.flashColor = 0xffffff;
        
        this.vignetteIntensity = 0;
        this.vignetteColor = 0x000000;
        
        this.chromaticAberration = 0;
        this.scanlineIntensity = 0;
        
        // Effect graphics
        this.effectsGraphics = null;
        this.postFxGraphics = null;
        
        // Cinematic bars
        this.topBar = null;
        this.bottomBar = null;
        this.cinematicMode = false;
        
        // Time effects
        this.timeScale = 1;
        this.timeScaleTarget = 1;
        
        // Preset effects
        this.presets = this.definePresets();
        
        // Active effects queue
        this.activeEffects = [];
    }
    
    /**
     * Define effect presets
     */
    definePresets() {
        return {
            // Impact effects
            'hit': {
                shake: { intensity: 5, duration: 200 },
                flash: { color: 0xff0000, alpha: 0.3, duration: 100 },
                chromaticAberration: { intensity: 10, duration: 150 }
            },
            'death': {
                shake: { intensity: 15, duration: 500 },
                flash: { color: 0xff0000, alpha: 0.5, duration: 200 },
                zoom: { target: 1.2, duration: 300 },
                slowmo: { scale: 0.3, duration: 1000 },
                vignette: { intensity: 0.8, duration: 1000 }
            },
            'boost': {
                shake: { intensity: 2, duration: 100 },
                zoom: { target: 0.95, duration: 200 },
                chromaticAberration: { intensity: 5, duration: 200 }
            },
            'powerup': {
                flash: { color: 0x00ffff, alpha: 0.2, duration: 150 },
                zoom: { target: 1.02, duration: 100 }
            },
            'nearMiss': {
                shake: { intensity: 3, duration: 150 },
                flash: { color: 0xffff00, alpha: 0.15, duration: 100 },
                slowmo: { scale: 0.7, duration: 200 }
            },
            'levelComplete': {
                flash: { color: 0xffffff, alpha: 0.5, duration: 500 },
                zoom: { target: 0.8, duration: 1000 },
                cinematic: { duration: 2000 }
            },
            'gravityShift': {
                shake: { intensity: 8, duration: 300 },
                chromaticAberration: { intensity: 15, duration: 300 },
                scanlines: { intensity: 0.3, duration: 200 }
            },
            'explosion': {
                shake: { intensity: 20, duration: 400 },
                flash: { color: 0xff8800, alpha: 0.4, duration: 150 },
                zoom: { target: 1.1, duration: 200 },
                chromaticAberration: { intensity: 20, duration: 250 }
            },
            'warp': {
                zoom: { target: 0.5, duration: 500 },
                flash: { color: 0x00ffff, alpha: 0.8, duration: 300 },
                chromaticAberration: { intensity: 30, duration: 500 },
                scanlines: { intensity: 0.5, duration: 400 }
            }
        };
    }
    
    /**
     * Initialize camera effects
     */
    initialize() {
        const { width, height } = this.camera;
        
        // Create graphics layers
        this.effectsGraphics = this.scene.add.graphics();
        this.effectsGraphics.setDepth(950);
        
        this.postFxGraphics = this.scene.add.graphics();
        this.postFxGraphics.setDepth(990);
        
        // Create cinematic bars
        this.createCinematicBars(width, height);
    }
    
    /**
     * Create cinematic letterbox bars
     */
    createCinematicBars(width, height) {
        const barHeight = height * 0.1;
        
        this.topBar = this.scene.add.graphics();
        this.topBar.fillStyle(0x000000, 1);
        this.topBar.fillRect(0, -barHeight, width, barHeight);
        this.topBar.setDepth(999);
        
        this.bottomBar = this.scene.add.graphics();
        this.bottomBar.fillStyle(0x000000, 1);
        this.bottomBar.fillRect(0, height, width, barHeight);
        this.bottomBar.setDepth(999);
    }
    
    /**
     * Play a preset effect
     */
    playPreset(presetName) {
        const preset = this.presets[presetName];
        if (!preset) {
            console.warn(`Unknown effect preset: ${presetName}`);
            return;
        }
        
        // Apply each effect in the preset
        if (preset.shake) {
            this.shake(preset.shake.intensity, preset.shake.duration);
        }
        
        if (preset.flash) {
            this.flash(preset.flash.color, preset.flash.alpha, preset.flash.duration);
        }
        
        if (preset.zoom) {
            this.zoomTo(preset.zoom.target, preset.zoom.duration);
        }
        
        if (preset.slowmo) {
            this.slowMotion(preset.slowmo.scale, preset.slowmo.duration);
        }
        
        if (preset.vignette) {
            this.vignette(preset.vignette.intensity, preset.vignette.duration);
        }
        
        if (preset.chromaticAberration) {
            this.chromaticAberrationEffect(preset.chromaticAberration.intensity, preset.chromaticAberration.duration);
        }
        
        if (preset.scanlines) {
            this.scanlines(preset.scanlines.intensity, preset.scanlines.duration);
        }
        
        if (preset.cinematic) {
            this.enterCinematicMode(preset.cinematic.duration);
        }
    }
    
    /**
     * Screen shake effect
     */
    shake(intensity = 10, duration = 200) {
        this.shakeIntensity = intensity;
        this.isShaking = true;
        
        this.scene.time.delayedCall(duration, () => {
            this.isShaking = false;
        });
    }
    
    /**
     * Continuous screen shake
     */
    startContinuousShake(intensity = 2) {
        this.shakeIntensity = intensity;
        this.isShaking = true;
    }
    
    /**
     * Stop continuous shake
     */
    stopContinuousShake() {
        this.isShaking = false;
        this.shakeIntensity = 0;
    }
    
    /**
     * Flash effect
     */
    flash(color = 0xffffff, alpha = 0.5, duration = 200) {
        this.flashColor = color;
        this.flashAlpha = alpha;
        
        this.scene.tweens.add({
            targets: this,
            flashAlpha: 0,
            duration: duration,
            ease: 'Power2'
        });
    }
    
    /**
     * Zoom effect
     */
    zoomTo(target = 1, duration = 500, ease = 'Power2') {
        this.zoomTarget = target;
        
        this.scene.tweens.add({
            targets: this.camera,
            zoom: target,
            duration: duration,
            ease: ease
        });
    }
    
    /**
     * Smooth zoom
     */
    smoothZoom(target, speed = 0.1) {
        this.zoomTarget = target;
        this.zoomSpeed = speed;
    }
    
    /**
     * Slow motion effect
     */
    slowMotion(scale = 0.5, duration = 1000, easeOut = true) {
        this.timeScale = scale;
        
        // Apply to scene time scale if available
        if (this.scene.time) {
            this.scene.time.timeScale = scale;
        }
        
        if (easeOut) {
            this.scene.tweens.add({
                targets: this,
                timeScale: 1,
                duration: duration,
                ease: 'Power2',
                onUpdate: () => {
                    if (this.scene.time) {
                        this.scene.time.timeScale = this.timeScale;
                    }
                }
            });
        } else {
            this.scene.time.delayedCall(duration / scale, () => {
                this.timeScale = 1;
                if (this.scene.time) {
                    this.scene.time.timeScale = 1;
                }
            });
        }
    }
    
    /**
     * Vignette effect
     */
    vignette(intensity = 0.5, duration = 500, color = 0x000000) {
        this.vignetteColor = color;
        this.vignetteIntensity = intensity;
        
        if (duration > 0) {
            this.scene.tweens.add({
                targets: this,
                vignetteIntensity: 0,
                duration: duration,
                ease: 'Power2',
                delay: duration * 0.5
            });
        }
    }
    
    /**
     * Set persistent vignette
     */
    setVignette(intensity, color = 0x000000) {
        this.vignetteColor = color;
        this.vignetteIntensity = intensity;
    }
    
    /**
     * Chromatic aberration effect
     */
    chromaticAberrationEffect(intensity = 10, duration = 200) {
        this.chromaticAberration = intensity;
        
        this.scene.tweens.add({
            targets: this,
            chromaticAberration: 0,
            duration: duration,
            ease: 'Power2'
        });
    }
    
    /**
     * Scanlines effect
     */
    scanlines(intensity = 0.3, duration = 300) {
        this.scanlineIntensity = intensity;
        
        this.scene.tweens.add({
            targets: this,
            scanlineIntensity: 0,
            duration: duration,
            ease: 'Power2'
        });
    }
    
    /**
     * Enter cinematic mode with letterbox bars
     */
    enterCinematicMode(duration = 500) {
        if (this.cinematicMode) return;
        
        this.cinematicMode = true;
        const { height } = this.camera;
        const barHeight = height * 0.1;
        
        // Animate bars in
        this.scene.tweens.add({
            targets: this.topBar,
            y: 0,
            duration: duration,
            ease: 'Power2'
        });
        
        this.scene.tweens.add({
            targets: this.bottomBar,
            y: -barHeight,
            duration: duration,
            ease: 'Power2'
        });
    }
    
    /**
     * Exit cinematic mode
     */
    exitCinematicMode(duration = 500) {
        if (!this.cinematicMode) return;
        
        const { height } = this.camera;
        const barHeight = height * 0.1;
        
        // Animate bars out
        this.scene.tweens.add({
            targets: this.topBar,
            y: -barHeight,
            duration: duration,
            ease: 'Power2'
        });
        
        this.scene.tweens.add({
            targets: this.bottomBar,
            y: 0,
            duration: duration,
            ease: 'Power2',
            onComplete: () => {
                this.cinematicMode = false;
            }
        });
    }
    
    /**
     * Camera follow with smooth lerp
     */
    followTarget(target, offsetX = 0, offsetY = 0, lerpX = 0.1, lerpY = 0.1) {
        const targetX = target.x + offsetX;
        const targetY = target.y + offsetY;
        
        this.camera.scrollX += (targetX - this.camera.scrollX - this.camera.width / 2) * lerpX;
        this.camera.scrollY += (targetY - this.camera.scrollY - this.camera.height / 2) * lerpY;
    }
    
    /**
     * Pan camera to position
     */
    panTo(x, y, duration = 1000, ease = 'Power2') {
        this.scene.tweens.add({
            targets: this.camera,
            scrollX: x - this.camera.width / 2,
            scrollY: y - this.camera.height / 2,
            duration: duration,
            ease: ease
        });
    }
    
    /**
     * Fade in effect
     */
    fadeIn(duration = 500, color = 0x000000, callback = null) {
        this.camera.fadeIn(duration, 
            (color >> 16) & 0xff,
            (color >> 8) & 0xff,
            color & 0xff
        );
        
        if (callback) {
            this.scene.time.delayedCall(duration, callback);
        }
    }
    
    /**
     * Fade out effect
     */
    fadeOut(duration = 500, color = 0x000000, callback = null) {
        this.camera.fadeOut(duration,
            (color >> 16) & 0xff,
            (color >> 8) & 0xff,
            color & 0xff
        );
        
        if (callback) {
            this.scene.time.delayedCall(duration, callback);
        }
    }
    
    /**
     * Fade to color and back
     */
    fadeToAndBack(color, alpha, holdDuration = 200, fadeDuration = 200) {
        this.flash(color, alpha, fadeDuration);
    }
    
    /**
     * Update camera effects
     */
    update(time, delta) {
        const { width, height } = this.camera;
        
        // Apply shake
        if (this.isShaking && this.shakeIntensity > 0) {
            const shakeX = (Math.random() - 0.5) * this.shakeIntensity;
            const shakeY = (Math.random() - 0.5) * this.shakeIntensity;
            
            this.camera.setScroll(
                this.camera.scrollX + shakeX,
                this.camera.scrollY + shakeY
            );
            
            if (!this.isShaking) {
                this.shakeIntensity *= this.shakeDecay;
                if (this.shakeIntensity < 0.1) {
                    this.shakeIntensity = 0;
                }
            }
        }
        
        // Smooth zoom
        if (Math.abs(this.camera.zoom - this.zoomTarget) > 0.001) {
            this.camera.zoom += (this.zoomTarget - this.camera.zoom) * this.zoomSpeed;
        }
        
        // Clear and redraw effects
        this.effectsGraphics.clear();
        this.postFxGraphics.clear();
        
        // Draw flash
        if (this.flashAlpha > 0.01) {
            this.effectsGraphics.fillStyle(this.flashColor, this.flashAlpha);
            this.effectsGraphics.fillRect(0, 0, width, height);
        }
        
        // Draw vignette
        if (this.vignetteIntensity > 0.01) {
            this.drawVignette(width, height);
        }
        
        // Draw scanlines
        if (this.scanlineIntensity > 0.01) {
            this.drawScanlines(width, height);
        }
        
        // Draw chromatic aberration hint (visual indicator)
        if (this.chromaticAberration > 0.5) {
            this.drawChromaticHint(width, height);
        }
    }
    
    /**
     * Draw vignette effect
     */
    drawVignette(width, height) {
        const centerX = width / 2;
        const centerY = height / 2;
        const maxRadius = Math.sqrt(centerX * centerX + centerY * centerY);
        
        const steps = 20;
        const innerRadius = maxRadius * (1 - this.vignetteIntensity);
        
        for (let i = 0; i < steps; i++) {
            const t = i / steps;
            const radius = innerRadius + (maxRadius - innerRadius) * t;
            const alpha = t * this.vignetteIntensity * 0.8;
            
            this.postFxGraphics.fillStyle(this.vignetteColor, alpha);
            this.postFxGraphics.fillCircle(centerX, centerY, radius);
        }
        
        // Clear the inner circle
        this.postFxGraphics.fillStyle(0x000000, 0);
        this.postFxGraphics.fillCircle(centerX, centerY, innerRadius);
    }
    
    /**
     * Draw scanlines effect
     */
    drawScanlines(width, height) {
        this.postFxGraphics.fillStyle(0x000000, this.scanlineIntensity);
        
        for (let y = 0; y < height; y += 4) {
            this.postFxGraphics.fillRect(0, y, width, 2);
        }
    }
    
    /**
     * Draw chromatic aberration hint
     */
    drawChromaticHint(width, height) {
        const offset = this.chromaticAberration * 0.5;
        
        // Red shift
        this.postFxGraphics.fillStyle(0xff0000, 0.1);
        this.postFxGraphics.fillRect(-offset, 0, offset, height);
        
        // Blue shift
        this.postFxGraphics.fillStyle(0x0000ff, 0.1);
        this.postFxGraphics.fillRect(width, 0, offset, height);
    }
    
    /**
     * Speed lines effect (for boost/high speed)
     */
    drawSpeedLines(intensity = 1) {
        const { width, height } = this.camera;
        const centerX = width / 2;
        const centerY = height / 2;
        
        const lineCount = Math.floor(20 * intensity);
        
        for (let i = 0; i < lineCount; i++) {
            const angle = Math.random() * Math.PI * 2;
            const innerRadius = 100 + Math.random() * 100;
            const outerRadius = innerRadius + 50 + Math.random() * 100;
            
            const x1 = centerX + Math.cos(angle) * innerRadius;
            const y1 = centerY + Math.sin(angle) * innerRadius;
            const x2 = centerX + Math.cos(angle) * outerRadius;
            const y2 = centerY + Math.sin(angle) * outerRadius;
            
            this.effectsGraphics.lineStyle(2, 0xffffff, 0.3 * intensity);
            this.effectsGraphics.lineBetween(x1, y1, x2, y2);
        }
    }
    
    /**
     * Pulse effect (expand and fade)
     */
    pulse(x, y, color = 0x00ffff, maxRadius = 100, duration = 500) {
        const graphics = this.scene.add.graphics();
        graphics.setDepth(900);
        
        let radius = 10;
        let alpha = 0.8;
        
        this.scene.tweens.add({
            targets: { radius: 10, alpha: 0.8 },
            radius: maxRadius,
            alpha: 0,
            duration: duration,
            ease: 'Power2',
            onUpdate: (tween) => {
                graphics.clear();
                graphics.lineStyle(3, color, tween.getValue('alpha'));
                graphics.strokeCircle(x, y, tween.getValue('radius'));
            },
            onComplete: () => {
                graphics.destroy();
            }
        });
    }
    
    /**
     * Reset all effects
     */
    reset() {
        this.shakeIntensity = 0;
        this.isShaking = false;
        this.flashAlpha = 0;
        this.vignetteIntensity = 0;
        this.chromaticAberration = 0;
        this.scanlineIntensity = 0;
        this.zoomTarget = 1;
        this.camera.zoom = 1;
        this.timeScale = 1;
        
        if (this.scene.time) {
            this.scene.time.timeScale = 1;
        }
        
        if (this.cinematicMode) {
            this.exitCinematicMode(0);
        }
        
        this.effectsGraphics.clear();
        this.postFxGraphics.clear();
    }
    
    /**
     * Destroy camera effects
     */
    destroy() {
        this.reset();
        
        if (this.effectsGraphics) this.effectsGraphics.destroy();
        if (this.postFxGraphics) this.postFxGraphics.destroy();
        if (this.topBar) this.topBar.destroy();
        if (this.bottomBar) this.bottomBar.destroy();
    }
}

// Export
if (typeof window !== 'undefined') {
    window.CameraEffects = CameraEffects;
}
