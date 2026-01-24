/**
 * GRAVSHIFT - Player Entity
 * Player-controlled vehicle with input handling
 */

class Player extends Vehicle {
    constructor(scene, x, y, vehicleType = 'BALANCED') {
        const config = VEHICLES[vehicleType] || VEHICLES.BALANCED;
        super(scene, x, y, config);
        
        this.vehicleType = vehicleType;
        this.inputManager = null;
        
        // Track position
        this.trackPosition = 0;
        this.lane = 1; // 0 = left, 1 = center, 2 = right
        
        // Boundaries
        this.minX = 100;
        this.maxX = GAME_CONFIG.WIDTH - 100;
        
        // States
        this.canControl = true;
        this.respawning = false;
        
        // Statistics
        this.totalDistance = 0;
        this.airTime = 0;
        this.isAirborne = false;
        
        // Visual sprite (will be created by scene)
        this.sprite = null;
        this.graphics = null;
    }
    
    /**
     * Set input manager
     */
    setInputManager(inputManager) {
        this.inputManager = inputManager;
    }
    
    /**
     * Set track boundaries
     */
    setBoundaries(minX, maxX) {
        this.minX = minX;
        this.maxX = maxX;
    }
    
    /**
     * Process player input
     */
    processInput(deltaTime) {
        if (!this.canControl || !this.inputManager || this.respawning) return;
        
        // Get input values
        const horizontal = this.inputManager.getHorizontalAxis();
        const boostIntensity = this.inputManager.getBoostIntensity();
        const brakeIntensity = this.inputManager.getBrakeIntensity();
        
        // Steering
        if (Math.abs(horizontal) > 0.1) {
            this.steer(horizontal, deltaTime);
        }
        
        // Boost
        if (boostIntensity > 0.5) {
            this.boost();
        } else {
            this.stopBoost();
        }
        
        // Brake
        if (brakeIntensity > 0.3) {
            this.brake(deltaTime);
        } else {
            // Auto accelerate in this game
            this.accelerate(deltaTime);
        }
    }
    
    /**
     * Update player
     */
    update(deltaTime) {
        // Process input
        this.processInput(deltaTime);
        
        // Update base vehicle
        super.update(deltaTime);
        
        // Constrain to track bounds
        this.x = MathUtils.clamp(this.x, this.minX, this.maxX);
        
        // Update track position based on speed
        const dt = deltaTime / 1000;
        this.trackPosition += this.speed * dt;
        this.totalDistance += this.speed * dt;
        
        // Update lane
        const trackWidth = this.maxX - this.minX;
        const relativeX = (this.x - this.minX) / trackWidth;
        this.lane = Math.floor(relativeX * 3);
        
        // Emit events for scoring
        if (this.isDrifting) {
            this.scene.events.emit('playerDrift', deltaTime);
        }
        
        // Update sprite position if exists
        if (this.sprite) {
            this.sprite.x = this.x;
            this.sprite.y = this.y;
            this.sprite.rotation = MathUtils.degToRad(this.rotation);
            this.sprite.alpha = this.isGhost ? 0.5 : 1;
        }
    }
    
    /**
     * Get current speed as percentage
     */
    getSpeedPercent() {
        return this.speed / (this.maxSpeed * this.boostMultiplier);
    }
    
    /**
     * Get nitro as percentage
     */
    getNitroPercent() {
        return this.nitro / this.nitroMax;
    }
    
    /**
     * Create visual representation
     */
    createVisuals(scene) {
        // Create graphics object for custom rendering
        this.graphics = scene.add.graphics();
        this.graphics.setDepth(100);
        
        // Try to use pre-generated sprite
        const textureKey = `vehicle_${this.vehicleType.toLowerCase()}`;
        if (scene.textures.exists(textureKey)) {
            this.sprite = scene.add.image(this.x, this.y, textureKey);
            this.sprite.setDepth(100);
        }
    }
    
    /**
     * Render player
     */
    render() {
        if (!this.graphics) return;
        
        this.graphics.clear();
        
        // Draw trail
        this.renderTrail(this.graphics);
        
        // If no sprite, draw manually
        if (!this.sprite) {
            this.renderVehicle(this.graphics);
        }
        
        // Draw effects
        this.renderEffects(this.graphics);
    }
    
    /**
     * Render vehicle shape
     */
    renderVehicle(graphics) {
        const x = this.x;
        const y = this.y;
        const w = this.width;
        const h = this.height;
        const rot = MathUtils.degToRad(this.rotation);
        
        // Transform points
        const points = [
            { x: 0, y: -h / 2 },      // Top
            { x: -w / 2, y: h / 2 },  // Bottom left
            { x: w / 2, y: h / 2 },   // Bottom right
        ];
        
        const transformed = points.map(p => {
            const rotated = MathUtils.rotatePoint(p.x, p.y, MathUtils.radToDeg(rot));
            return { x: x + rotated.x, y: y + rotated.y };
        });
        
        // Glow
        if (this.glowIntensity > 1 || this.isBoosting) {
            for (let i = 3; i > 0; i--) {
                const alpha = 0.15 / i;
                const scale = 1 + i * 0.1;
                graphics.fillStyle(this.color, alpha);
                graphics.fillTriangle(
                    x + (transformed[0].x - x) * scale,
                    y + (transformed[0].y - y) * scale,
                    x + (transformed[1].x - x) * scale,
                    y + (transformed[1].y - y) * scale,
                    x + (transformed[2].x - x) * scale,
                    y + (transformed[2].y - y) * scale
                );
            }
        }
        
        // Main body
        graphics.fillStyle(this.color, this.isGhost ? 0.5 : 1);
        graphics.fillTriangle(
            transformed[0].x, transformed[0].y,
            transformed[1].x, transformed[1].y,
            transformed[2].x, transformed[2].y
        );
        
        // Outline
        graphics.lineStyle(2, ColorUtils.lighten(this.color, 0.3), this.isGhost ? 0.3 : 0.8);
        graphics.strokeTriangle(
            transformed[0].x, transformed[0].y,
            transformed[1].x, transformed[1].y,
            transformed[2].x, transformed[2].y
        );
        
        // Cockpit
        const cockpitPoints = [
            { x: 0, y: -h / 4 },
            { x: -w / 4, y: h / 4 },
            { x: w / 4, y: h / 4 },
        ];
        
        const cockpitTransformed = cockpitPoints.map(p => {
            const rotated = MathUtils.rotatePoint(p.x, p.y, MathUtils.radToDeg(rot));
            return { x: x + rotated.x, y: y + rotated.y };
        });
        
        graphics.fillStyle(ColorUtils.darken(this.color, 0.4), this.isGhost ? 0.3 : 0.7);
        graphics.fillTriangle(
            cockpitTransformed[0].x, cockpitTransformed[0].y,
            cockpitTransformed[1].x, cockpitTransformed[1].y,
            cockpitTransformed[2].x, cockpitTransformed[2].y
        );
    }
    
    /**
     * Render special effects
     */
    renderEffects(graphics) {
        // Engine flames
        if (this.speed > this.maxSpeed * 0.2) {
            const flameLength = 10 + (this.speed / this.maxSpeed) * 20;
            const flameColor = this.isBoosting ? 0xff8800 : this.color;
            
            const leftEngine = MathUtils.rotatePoint(-this.width / 4, this.height / 2, this.rotation);
            const rightEngine = MathUtils.rotatePoint(this.width / 4, this.height / 2, this.rotation);
            
            // Flame glow
            graphics.fillStyle(flameColor, 0.5);
            graphics.fillCircle(this.x + leftEngine.x, this.y + leftEngine.y + flameLength / 2, 8);
            graphics.fillCircle(this.x + rightEngine.x, this.y + rightEngine.y + flameLength / 2, 8);
            
            // Flame core
            graphics.fillStyle(0xffffff, 0.8);
            graphics.fillCircle(this.x + leftEngine.x, this.y + leftEngine.y, 4);
            graphics.fillCircle(this.x + rightEngine.x, this.y + rightEngine.y, 4);
        }
        
        // Shield effect
        if (this.isInvincible) {
            const pulse = Math.sin(Date.now() / 100) * 0.3 + 0.7;
            graphics.lineStyle(3, 0xffff00, pulse * 0.5);
            graphics.strokeCircle(this.x, this.y, this.width * 0.9);
            
            graphics.lineStyle(1, 0xffff00, pulse * 0.2);
            graphics.strokeCircle(this.x, this.y, this.width * 1.1);
        }
        
        // Boost effect
        if (this.isBoosting) {
            const speedLines = 5;
            for (let i = 0; i < speedLines; i++) {
                const offsetX = (Math.random() - 0.5) * this.width;
                const startY = this.y + this.height / 2;
                const length = 20 + Math.random() * 30;
                
                graphics.lineStyle(2, 0xff8800, 0.5);
                graphics.lineBetween(
                    this.x + offsetX,
                    startY,
                    this.x + offsetX,
                    startY + length
                );
            }
        }
    }
    
    /**
     * Render trail
     */
    renderTrail(graphics) {
        if (this.trailPoints.length < 2) return;
        
        const now = Date.now();
        
        for (let i = 0; i < this.trailPoints.length - 1; i++) {
            const age = (now - this.trailPoints[i].time) / 500;
            const alpha = (1 - age) * (1 - i / this.trailPoints.length) * 0.6;
            const width = (1 - i / this.trailPoints.length) * 6;
            
            if (alpha <= 0) continue;
            
            graphics.lineStyle(width, this.color, alpha);
            graphics.lineBetween(
                this.trailPoints[i].x - this.width / 3,
                this.trailPoints[i].y,
                this.trailPoints[i + 1].x - this.width / 3,
                this.trailPoints[i + 1].y
            );
            graphics.lineBetween(
                this.trailPoints[i].x + this.width / 3,
                this.trailPoints[i].y,
                this.trailPoints[i + 1].x + this.width / 3,
                this.trailPoints[i + 1].y
            );
        }
    }
    
    /**
     * Handle respawn
     */
    respawn(x, y, invincibilityTime = 2000) {
        this.respawning = true;
        this.x = x;
        this.y = y;
        this.speed = 0;
        this.rotation = 0;
        
        // Grant temporary invincibility
        this.isInvincible = true;
        this.invincibleTimer = invincibilityTime;
        
        // Flash effect
        if (this.sprite) {
            this.scene.tweens.add({
                targets: this.sprite,
                alpha: { from: 0, to: 1 },
                duration: 100,
                repeat: 5,
                onComplete: () => {
                    this.respawning = false;
                },
            });
        } else {
            this.scene.time.delayedCall(600, () => {
                this.respawning = false;
            });
        }
    }
    
    /**
     * Destroy player
     */
    destroy() {
        if (this.sprite) {
            this.sprite.destroy();
        }
        if (this.graphics) {
            this.graphics.destroy();
        }
    }
}

// Export
if (typeof window !== 'undefined') {
    window.Player = Player;
}
