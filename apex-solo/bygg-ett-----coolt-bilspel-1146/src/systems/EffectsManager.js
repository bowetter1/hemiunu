/**
 * GRAVSHIFT - Effects Manager
 * Post-processing and visual effects
 */

class EffectsManager {
    constructor(scene) {
        this.scene = scene;
        
        // Effect states
        this.screenFlash = { active: false, color: 0xffffff, alpha: 0, duration: 0, time: 0 };
        this.screenFade = { active: false, color: 0x000000, alpha: 0, target: 0, speed: 0.01 };
        this.slowMotion = { active: false, scale: 1, target: 1 };
        this.colorShift = { active: false, hue: 0, speed: 0 };
        this.scanlines = { active: false, intensity: 0 };
        this.glitch = { active: false, intensity: 0, duration: 0, time: 0 };
        
        // Graphics objects for effects
        this.overlayGraphics = null;
        this.effectsContainer = null;
    }
    
    /**
     * Initialize effect graphics
     */
    init() {
        // Create overlay for screen effects
        this.overlayGraphics = this.scene.add.graphics();
        this.overlayGraphics.setDepth(1000);
        
        // Create container for effect objects
        this.effectsContainer = this.scene.add.container(0, 0);
        this.effectsContainer.setDepth(999);
    }
    
    /**
     * Flash the screen
     */
    flash(color = 0xffffff, duration = 100, intensity = 1) {
        this.screenFlash = {
            active: true,
            color: color,
            alpha: intensity,
            duration: duration,
            time: 0,
        };
    }
    
    /**
     * Fade screen to color
     */
    fadeOut(color = 0x000000, duration = 500) {
        return new Promise(resolve => {
            this.screenFade = {
                active: true,
                color: color,
                alpha: 0,
                target: 1,
                speed: 1 / duration * 16,
                callback: resolve,
            };
        });
    }
    
    /**
     * Fade screen from color
     */
    fadeIn(color = 0x000000, duration = 500) {
        return new Promise(resolve => {
            this.screenFade = {
                active: true,
                color: color,
                alpha: 1,
                target: 0,
                speed: 1 / duration * 16,
                callback: resolve,
            };
        });
    }
    
    /**
     * Enable slow motion
     */
    slowMo(scale = 0.3, duration = 0) {
        this.slowMotion = {
            active: true,
            scale: this.scene.time.timeScale,
            target: scale,
        };
        
        if (duration > 0) {
            this.scene.time.delayedCall(duration * scale, () => {
                this.endSlowMo();
            });
        }
    }
    
    /**
     * End slow motion
     */
    endSlowMo() {
        this.slowMotion = {
            active: true,
            scale: this.scene.time.timeScale,
            target: 1,
        };
    }
    
    /**
     * Start color cycling effect
     */
    startColorShift(speed = 0.001) {
        this.colorShift = {
            active: true,
            hue: 0,
            speed: speed,
        };
    }
    
    /**
     * Stop color shift
     */
    stopColorShift() {
        this.colorShift.active = false;
    }
    
    /**
     * Enable scanline effect
     */
    enableScanlines(intensity = 0.3) {
        this.scanlines = {
            active: true,
            intensity: intensity,
        };
    }
    
    /**
     * Disable scanlines
     */
    disableScanlines() {
        this.scanlines.active = false;
    }
    
    /**
     * Trigger glitch effect
     */
    glitchEffect(intensity = 0.5, duration = 200) {
        this.glitch = {
            active: true,
            intensity: intensity,
            duration: duration,
            time: 0,
        };
    }
    
    /**
     * Create impact effect at position
     */
    impact(x, y, color = 0xffffff, size = 100) {
        // Create expanding ring
        const ring = this.scene.add.graphics();
        ring.lineStyle(4, color, 1);
        ring.strokeCircle(x, y, 10);
        this.effectsContainer.add(ring);
        
        // Animate ring
        this.scene.tweens.add({
            targets: ring,
            scaleX: size / 10,
            scaleY: size / 10,
            alpha: 0,
            duration: 300,
            ease: 'Quad.easeOut',
            onComplete: () => ring.destroy(),
        });
        
        // Flash
        this.flash(color, 50, 0.3);
    }
    
    /**
     * Create speed lines effect
     */
    speedLines(intensity = 1) {
        const width = this.scene.scale.width;
        const height = this.scene.scale.height;
        const centerX = width / 2;
        const centerY = height / 2;
        
        for (let i = 0; i < 10 * intensity; i++) {
            const angle = Math.random() * Math.PI * 2;
            const distance = Math.random() * 200 + 100;
            
            const startX = centerX + Math.cos(angle) * distance;
            const startY = centerY + Math.sin(angle) * distance;
            const endX = centerX + Math.cos(angle) * (distance + 100 + Math.random() * 100);
            const endY = centerY + Math.sin(angle) * (distance + 100 + Math.random() * 100);
            
            const line = this.scene.add.graphics();
            line.lineStyle(2, 0xffffff, 0.5);
            line.lineBetween(startX, startY, endX, endY);
            this.effectsContainer.add(line);
            
            this.scene.tweens.add({
                targets: line,
                alpha: 0,
                duration: 200,
                onComplete: () => line.destroy(),
            });
        }
    }
    
    /**
     * Create warp tunnel effect
     */
    warpTunnel(duration = 1000) {
        const width = this.scene.scale.width;
        const height = this.scene.scale.height;
        const centerX = width / 2;
        const centerY = height / 2;
        
        for (let i = 0; i < 20; i++) {
            this.scene.time.delayedCall(i * 50, () => {
                const ring = this.scene.add.graphics();
                ring.lineStyle(3, ColorUtils.rainbow(i / 20), 0.8);
                ring.strokeCircle(centerX, centerY, 50);
                ring.setScale(0.1);
                this.effectsContainer.add(ring);
                
                this.scene.tweens.add({
                    targets: ring,
                    scaleX: 10,
                    scaleY: 10,
                    alpha: 0,
                    duration: 500,
                    ease: 'Quad.easeIn',
                    onComplete: () => ring.destroy(),
                });
            });
        }
    }
    
    /**
     * Create checkpoint celebration effect
     */
    checkpointCelebration(x, y, color) {
        // Multiple expanding rings
        for (let i = 0; i < 3; i++) {
            this.scene.time.delayedCall(i * 100, () => {
                this.impact(x, y, color, 150);
            });
        }
        
        // Star burst
        for (let i = 0; i < 8; i++) {
            const angle = (i / 8) * Math.PI * 2;
            const star = this.scene.add.graphics();
            star.fillStyle(color, 1);
            star.fillCircle(0, 0, 5);
            star.setPosition(x, y);
            this.effectsContainer.add(star);
            
            this.scene.tweens.add({
                targets: star,
                x: x + Math.cos(angle) * 150,
                y: y + Math.sin(angle) * 150,
                alpha: 0,
                scale: 0,
                duration: 500,
                ease: 'Quad.easeOut',
                onComplete: () => star.destroy(),
            });
        }
    }
    
    /**
     * Update all effects
     */
    update(deltaTime) {
        if (!this.overlayGraphics) return;
        
        this.overlayGraphics.clear();
        
        const width = this.scene.scale.width;
        const height = this.scene.scale.height;
        
        // Update screen flash
        if (this.screenFlash.active) {
            this.screenFlash.time += deltaTime;
            const progress = this.screenFlash.time / this.screenFlash.duration;
            
            if (progress >= 1) {
                this.screenFlash.active = false;
            } else {
                const alpha = this.screenFlash.alpha * (1 - progress);
                this.overlayGraphics.fillStyle(this.screenFlash.color, alpha);
                this.overlayGraphics.fillRect(0, 0, width, height);
            }
        }
        
        // Update screen fade
        if (this.screenFade.active) {
            const diff = this.screenFade.target - this.screenFade.alpha;
            
            if (Math.abs(diff) < 0.01) {
                this.screenFade.alpha = this.screenFade.target;
                this.screenFade.active = false;
                if (this.screenFade.callback) {
                    this.screenFade.callback();
                }
            } else {
                this.screenFade.alpha += diff * this.screenFade.speed * deltaTime;
            }
            
            if (this.screenFade.alpha > 0) {
                this.overlayGraphics.fillStyle(this.screenFade.color, this.screenFade.alpha);
                this.overlayGraphics.fillRect(0, 0, width, height);
            }
        }
        
        // Update slow motion
        if (this.slowMotion.active) {
            const diff = this.slowMotion.target - this.slowMotion.scale;
            
            if (Math.abs(diff) < 0.01) {
                this.scene.time.timeScale = this.slowMotion.target;
                this.slowMotion.active = false;
            } else {
                this.slowMotion.scale += diff * 0.1;
                this.scene.time.timeScale = this.slowMotion.scale;
            }
        }
        
        // Update color shift
        if (this.colorShift.active) {
            this.colorShift.hue += this.colorShift.speed * deltaTime;
            if (this.colorShift.hue > 1) this.colorShift.hue -= 1;
        }
        
        // Update scanlines
        if (this.scanlines.active) {
            this.overlayGraphics.fillStyle(0x000000, this.scanlines.intensity);
            for (let y = 0; y < height; y += 4) {
                this.overlayGraphics.fillRect(0, y, width, 2);
            }
        }
        
        // Update glitch
        if (this.glitch.active) {
            this.glitch.time += deltaTime;
            
            if (this.glitch.time >= this.glitch.duration) {
                this.glitch.active = false;
            } else {
                // Random horizontal displacement lines
                const numLines = Math.floor(5 * this.glitch.intensity);
                for (let i = 0; i < numLines; i++) {
                    const y = Math.random() * height;
                    const h = Math.random() * 10 + 5;
                    const offset = (Math.random() - 0.5) * 50 * this.glitch.intensity;
                    
                    this.overlayGraphics.fillStyle(0xff0000, 0.3);
                    this.overlayGraphics.fillRect(offset, y, width, h);
                    this.overlayGraphics.fillStyle(0x00ffff, 0.3);
                    this.overlayGraphics.fillRect(-offset, y + 2, width, h);
                }
            }
        }
    }
    
    /**
     * Get current color shift hue
     */
    getColorShiftHue() {
        return this.colorShift.active ? this.colorShift.hue : 0;
    }
    
    /**
     * Clean up
     */
    destroy() {
        if (this.overlayGraphics) {
            this.overlayGraphics.destroy();
        }
        if (this.effectsContainer) {
            this.effectsContainer.destroy();
        }
    }
}

// Export
if (typeof window !== 'undefined') {
    window.EffectsManager = EffectsManager;
}
