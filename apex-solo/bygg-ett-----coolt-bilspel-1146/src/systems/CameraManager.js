/**
 * GRAVSHIFT - Camera Manager
 * Dynamic camera with rotation, shake, and zoom effects
 */

class CameraManager {
    constructor(scene) {
        this.scene = scene;
        this.camera = scene.cameras.main;
        
        // Camera state
        this.targetX = 0;
        this.targetY = 0;
        this.targetZoom = 1;
        this.targetRotation = 0;
        
        // Shake state
        this.shakeIntensity = 0;
        this.shakeDuration = 0;
        this.shakeTime = 0;
        
        // Smoothing
        this.followSpeed = 0.1;
        this.zoomSpeed = 0.05;
        this.rotationSpeed = 0.03;
        
        // Bounds
        this.minZoom = 0.5;
        this.maxZoom = 2;
        
        // Effects
        this.chromaticAberration = 0;
        this.vignette = 0;
        this.flash = { active: false, color: 0xffffff, alpha: 0, duration: 0 };
    }
    
    /**
     * Set camera target position
     */
    setTarget(x, y) {
        this.targetX = x;
        this.targetY = y;
    }
    
    /**
     * Set camera zoom
     */
    setZoom(zoom) {
        this.targetZoom = MathUtils.clamp(zoom, this.minZoom, this.maxZoom);
    }
    
    /**
     * Set camera rotation (in degrees, relative to gravity)
     */
    setRotation(degrees) {
        this.targetRotation = MathUtils.degToRad(degrees);
    }
    
    /**
     * Add rotation (for smooth gravity shifts)
     */
    addRotation(degrees) {
        this.targetRotation += MathUtils.degToRad(degrees);
    }
    
    /**
     * Shake the camera
     */
    shake(intensity = 10, duration = 200) {
        this.shakeIntensity = Math.max(this.shakeIntensity, intensity);
        this.shakeDuration = Math.max(this.shakeDuration, duration);
        this.shakeTime = 0;
    }
    
    /**
     * Flash the screen
     */
    flash(color = 0xffffff, duration = 100, intensity = 1) {
        this.flash.active = true;
        this.flash.color = color;
        this.flash.alpha = intensity;
        this.flash.duration = duration;
        this.flash.time = 0;
    }
    
    /**
     * Zoom burst effect (zoom in then out)
     */
    zoomBurst(amount = 0.2, duration = 300) {
        const originalZoom = this.targetZoom;
        this.setZoom(this.targetZoom + amount);
        
        this.scene.time.delayedCall(duration, () => {
            this.setZoom(originalZoom);
        });
    }
    
    /**
     * Set chromatic aberration intensity
     */
    setChromaticAberration(intensity) {
        this.chromaticAberration = MathUtils.clamp(intensity, 0, 1);
    }
    
    /**
     * Set vignette intensity
     */
    setVignette(intensity) {
        this.vignette = MathUtils.clamp(intensity, 0, 1);
    }
    
    /**
     * Follow a game object
     */
    follow(target, offsetX = 0, offsetY = 0) {
        this.followTarget = target;
        this.followOffsetX = offsetX;
        this.followOffsetY = offsetY;
    }
    
    /**
     * Stop following
     */
    stopFollow() {
        this.followTarget = null;
    }
    
    /**
     * Update camera
     */
    update(deltaTime) {
        const dt = deltaTime / 1000;
        
        // Update follow target
        if (this.followTarget) {
            this.targetX = this.followTarget.x + this.followOffsetX;
            this.targetY = this.followTarget.y + this.followOffsetY;
        }
        
        // Smooth follow position
        const currentX = this.camera.scrollX + this.camera.width / 2;
        const currentY = this.camera.scrollY + this.camera.height / 2;
        
        const newX = MathUtils.lerp(currentX, this.targetX, this.followSpeed);
        const newY = MathUtils.lerp(currentY, this.targetY, this.followSpeed);
        
        this.camera.scrollX = newX - this.camera.width / 2;
        this.camera.scrollY = newY - this.camera.height / 2;
        
        // Smooth zoom
        this.camera.zoom = MathUtils.lerp(this.camera.zoom, this.targetZoom, this.zoomSpeed);
        
        // Smooth rotation
        const rotationDiff = MathUtils.angleDifference(
            MathUtils.radToDeg(this.camera.rotation),
            MathUtils.radToDeg(this.targetRotation)
        );
        this.camera.rotation += MathUtils.degToRad(rotationDiff * this.rotationSpeed);
        
        // Update shake
        if (this.shakeDuration > 0) {
            this.shakeTime += deltaTime;
            
            if (this.shakeTime < this.shakeDuration) {
                const progress = this.shakeTime / this.shakeDuration;
                const decay = 1 - progress;
                const intensity = this.shakeIntensity * decay;
                
                const offsetX = (Math.random() - 0.5) * 2 * intensity;
                const offsetY = (Math.random() - 0.5) * 2 * intensity;
                
                this.camera.scrollX += offsetX;
                this.camera.scrollY += offsetY;
            } else {
                this.shakeDuration = 0;
                this.shakeIntensity = 0;
            }
        }
        
        // Update flash
        if (this.flash.active) {
            this.flash.time = (this.flash.time || 0) + deltaTime;
            const progress = this.flash.time / this.flash.duration;
            
            if (progress >= 1) {
                this.flash.active = false;
                this.flash.alpha = 0;
            } else {
                this.flash.alpha = (1 - progress) * this.flash.alpha;
            }
        }
    }
    
    /**
     * Get current rotation in degrees
     */
    getRotationDegrees() {
        return MathUtils.radToDeg(this.camera.rotation);
    }
    
    /**
     * Convert screen position to world position
     */
    screenToWorld(screenX, screenY) {
        return this.camera.getWorldPoint(screenX, screenY);
    }
    
    /**
     * Convert world position to screen position
     */
    worldToScreen(worldX, worldY) {
        const point = new Phaser.Math.Vector2(worldX, worldY);
        return {
            x: (point.x - this.camera.scrollX) * this.camera.zoom,
            y: (point.y - this.camera.scrollY) * this.camera.zoom,
        };
    }
    
    /**
     * Check if position is visible on screen
     */
    isVisible(x, y, margin = 100) {
        const bounds = this.camera.worldView;
        return x >= bounds.x - margin &&
               x <= bounds.x + bounds.width + margin &&
               y >= bounds.y - margin &&
               y <= bounds.y + bounds.height + margin;
    }
    
    /**
     * Get camera bounds
     */
    getBounds() {
        return this.camera.worldView;
    }
    
    /**
     * Reset camera to default state
     */
    reset() {
        this.targetX = 0;
        this.targetY = 0;
        this.targetZoom = 1;
        this.targetRotation = 0;
        this.shakeIntensity = 0;
        this.shakeDuration = 0;
        this.chromaticAberration = 0;
        this.vignette = 0;
        this.flash.active = false;
        
        this.camera.scrollX = 0;
        this.camera.scrollY = 0;
        this.camera.zoom = 1;
        this.camera.rotation = 0;
    }
    
    /**
     * Apply speed-based effects
     */
    applySpeedEffects(speed, maxSpeed) {
        const speedRatio = speed / maxSpeed;
        
        // Zoom out slightly at high speed
        const zoomOffset = speedRatio * 0.1;
        this.setZoom(1 - zoomOffset);
        
        // Add chromatic aberration at high speed
        this.setChromaticAberration(speedRatio * 0.3);
        
        // Add vignette at very high speed
        if (speedRatio > 0.8) {
            this.setVignette((speedRatio - 0.8) * 2);
        } else {
            this.setVignette(0);
        }
    }
}

// Export
if (typeof window !== 'undefined') {
    window.CameraManager = CameraManager;
}
