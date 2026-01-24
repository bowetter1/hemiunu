/**
 * GRAVSHIFT - Vehicle Base Class
 * Base class for all vehicles in the game
 */

class Vehicle {
    constructor(scene, x, y, config) {
        this.scene = scene;
        this.x = x;
        this.y = y;
        this.config = config;
        
        // Physics properties
        this.velocity = { x: 0, y: 0 };
        this.acceleration = 0;
        this.speed = 0;
        this.maxSpeed = config.maxSpeed || GAME_CONFIG.PLAYER.MAX_SPEED;
        this.accelerationRate = config.acceleration || GAME_CONFIG.PLAYER.ACCELERATION;
        this.handling = config.handling || GAME_CONFIG.PLAYER.TURN_SPEED;
        this.boostMultiplier = config.boost || GAME_CONFIG.PLAYER.BOOST_MULTIPLIER;
        
        // Rotation (relative to track)
        this.rotation = 0;
        this.targetRotation = 0;
        this.worldRotation = 0;
        
        // State
        this.active = true;
        this.visible = true;
        this.width = 50;
        this.height = 60;
        
        // Power-up states
        this.isBoosting = false;
        this.isInvincible = false;
        this.isGhost = false;
        this.boostTimer = 0;
        this.invincibleTimer = 0;
        this.ghostTimer = 0;
        
        // Nitro
        this.nitro = GAME_CONFIG.PLAYER.NITRO_MAX;
        this.nitroMax = GAME_CONFIG.PLAYER.NITRO_MAX;
        
        // Drift
        this.isDrifting = false;
        this.driftAmount = 0;
        this.driftDirection = 0;
        
        // Trail
        this.trailPoints = [];
        this.maxTrailPoints = 20;
        
        // Visual
        this.color = config.color || 0x00ffff;
        this.glowIntensity = 1;
    }
    
    /**
     * Accelerate the vehicle
     */
    accelerate(deltaTime) {
        const dt = deltaTime / 1000;
        const targetSpeed = this.maxSpeed * (this.isBoosting ? this.boostMultiplier : 1);
        
        this.speed = MathUtils.lerp(this.speed, targetSpeed, this.accelerationRate / 1000 * dt);
        
        // Drain nitro when boosting
        if (this.isBoosting && this.boostTimer <= 0) {
            this.nitro -= GAME_CONFIG.PLAYER.NITRO_DRAIN * dt;
            if (this.nitro <= 0) {
                this.nitro = 0;
                this.isBoosting = false;
            }
        }
    }
    
    /**
     * Brake/decelerate
     */
    brake(deltaTime) {
        const dt = deltaTime / 1000;
        this.speed = MathUtils.lerp(this.speed, 0, GAME_CONFIG.PLAYER.BRAKE_FORCE / 1000 * dt);
    }
    
    /**
     * Steer left/right
     */
    steer(direction, deltaTime) {
        const dt = deltaTime / 1000;
        const steerAmount = direction * this.handling * dt * 60;
        
        // Apply steering based on speed
        const speedFactor = Math.min(this.speed / (this.maxSpeed * 0.5), 1);
        this.x += steerAmount * speedFactor * 30;
        
        // Visual tilt
        this.targetRotation = direction * 15;
        
        // Check for drift
        if (Math.abs(direction) > 0.7 && this.speed > this.maxSpeed * 0.6) {
            this.isDrifting = true;
            this.driftAmount = Math.abs(direction);
            this.driftDirection = Math.sign(direction);
        } else {
            this.isDrifting = false;
            this.driftAmount = 0;
        }
    }
    
    /**
     * Activate boost
     */
    boost() {
        if (this.nitro > 20 || this.boostTimer > 0) {
            this.isBoosting = true;
        }
    }
    
    /**
     * Stop boosting
     */
    stopBoost() {
        if (this.boostTimer <= 0) {
            this.isBoosting = false;
        }
    }
    
    /**
     * Apply power-up effect
     */
    applyPowerup(type, duration) {
        switch (type) {
            case 'BOOST':
                this.isBoosting = true;
                this.boostTimer = duration;
                break;
            case 'SHIELD':
                this.isInvincible = true;
                this.invincibleTimer = duration;
                break;
            case 'GHOST':
                this.isGhost = true;
                this.ghostTimer = duration;
                break;
        }
    }
    
    /**
     * Take damage
     */
    takeDamage() {
        if (this.isInvincible || this.isGhost) return false;
        
        // Slow down
        this.speed *= 0.5;
        
        // Break combo
        this.scene.events.emit('vehicleHit', this);
        
        return true;
    }
    
    /**
     * Update vehicle state
     */
    update(deltaTime) {
        const dt = deltaTime / 1000;
        
        // Regenerate nitro
        if (!this.isBoosting) {
            this.nitro = Math.min(this.nitroMax, this.nitro + GAME_CONFIG.PLAYER.NITRO_REGEN * dt);
        }
        
        // Update power-up timers
        if (this.boostTimer > 0) {
            this.boostTimer -= deltaTime;
            if (this.boostTimer <= 0) {
                this.isBoosting = false;
            }
        }
        
        if (this.invincibleTimer > 0) {
            this.invincibleTimer -= deltaTime;
            if (this.invincibleTimer <= 0) {
                this.isInvincible = false;
            }
        }
        
        if (this.ghostTimer > 0) {
            this.ghostTimer -= deltaTime;
            if (this.ghostTimer <= 0) {
                this.isGhost = false;
            }
        }
        
        // Smooth rotation
        this.rotation = MathUtils.lerp(this.rotation, this.targetRotation, 0.15);
        
        // Reset target rotation
        this.targetRotation = MathUtils.lerp(this.targetRotation, 0, 0.1);
        
        // Update trail
        this.updateTrail();
        
        // Apply friction
        this.speed *= GAME_CONFIG.PLAYER.DRIFT_FACTOR;
        
        // Update glow based on state
        if (this.isBoosting) {
            this.glowIntensity = 2;
        } else if (this.isInvincible) {
            this.glowIntensity = 1.5;
        } else {
            this.glowIntensity = 1;
        }
    }
    
    /**
     * Update trail points
     */
    updateTrail() {
        if (this.speed > this.maxSpeed * 0.3) {
            this.trailPoints.unshift({ x: this.x, y: this.y, time: Date.now() });
            
            if (this.trailPoints.length > this.maxTrailPoints) {
                this.trailPoints.pop();
            }
        }
        
        // Remove old trail points
        const now = Date.now();
        this.trailPoints = this.trailPoints.filter(p => now - p.time < 500);
    }
    
    /**
     * Get bounding box
     */
    getBounds() {
        return {
            x: this.x - this.width / 2,
            y: this.y - this.height / 2,
            width: this.width,
            height: this.height,
            centerX: this.x,
            centerY: this.y,
        };
    }
    
    /**
     * Render vehicle using Phaser Graphics (properly)
     * Note: This base implementation draws at world position
     * Subclasses should override for custom rendering
     */
    render(graphics) {
        if (!this.visible || !graphics) return;
        
        graphics.clear();
        
        // Draw trail
        this.renderTrail(graphics);
        
        // Draw vehicle body with rotation via transformed points
        const x = this.x;
        const y = this.y;
        const w = this.width;
        const h = this.height;
        
        // Calculate rotated triangle points
        const points = [
            { x: 0, y: -h / 2 },      // Top
            { x: -w / 2, y: h / 2 },  // Bottom left
            { x: w / 2, y: h / 2 },   // Bottom right
        ];
        
        const transformed = points.map(p => {
            const rotated = MathUtils.rotatePoint(p.x, p.y, this.rotation);
            return { x: x + rotated.x, y: y + rotated.y };
        });
        
        // Glow effect
        if (this.glowIntensity > 1) {
            for (let i = 3; i > 0; i--) {
                const alpha = (this.glowIntensity - 1) * 0.2 / i;
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
        
        // Cockpit
        const cockpitPoints = [
            { x: 0, y: -h / 4 },
            { x: -w / 4, y: h / 4 },
            { x: w / 4, y: h / 4 },
        ];
        
        const cockpitTransformed = cockpitPoints.map(p => {
            const rotated = MathUtils.rotatePoint(p.x, p.y, this.rotation);
            return { x: x + rotated.x, y: y + rotated.y };
        });
        
        graphics.fillStyle(ColorUtils.darken(this.color, 0.4), this.isGhost ? 0.3 : 0.8);
        graphics.fillTriangle(
            cockpitTransformed[0].x, cockpitTransformed[0].y,
            cockpitTransformed[1].x, cockpitTransformed[1].y,
            cockpitTransformed[2].x, cockpitTransformed[2].y
        );
        
        // Engine glow
        if (this.speed > 0) {
            const engineGlow = this.isBoosting ? 1 : this.speed / this.maxSpeed;
            const leftEngine = MathUtils.rotatePoint(-w / 4, h / 2, this.rotation);
            const rightEngine = MathUtils.rotatePoint(w / 4, h / 2, this.rotation);
            
            graphics.fillStyle(this.isBoosting ? 0xff8800 : this.color, engineGlow);
            graphics.fillCircle(x + leftEngine.x, y + leftEngine.y, 4 + engineGlow * 4);
            graphics.fillCircle(x + rightEngine.x, y + rightEngine.y, 4 + engineGlow * 4);
        }
        
        // Shield effect
        if (this.isInvincible) {
            const pulse = Math.sin(Date.now() / 100) * 0.3 + 0.5;
            graphics.lineStyle(3, 0xffff00, pulse);
            graphics.strokeCircle(x, y, w * 0.8);
        }
    }
    
    /**
     * Render vehicle trail
     */
    renderTrail(graphics) {
        if (this.trailPoints.length < 2) return;
        
        const now = Date.now();
        
        for (let i = 0; i < this.trailPoints.length - 1; i++) {
            const age = (now - this.trailPoints[i].time) / 500;
            const alpha = (1 - age) * (1 - i / this.trailPoints.length) * 0.5;
            const width = (1 - i / this.trailPoints.length) * 4;
            
            if (alpha <= 0) continue;
            
            graphics.lineStyle(width, this.color, alpha);
            graphics.lineBetween(
                this.trailPoints[i].x,
                this.trailPoints[i].y,
                this.trailPoints[i + 1].x,
                this.trailPoints[i + 1].y
            );
        }
    }
    
    /**
     * Reset vehicle state
     */
    reset(x, y) {
        this.x = x;
        this.y = y;
        this.speed = 0;
        this.rotation = 0;
        this.targetRotation = 0;
        this.isBoosting = false;
        this.isInvincible = false;
        this.isGhost = false;
        this.boostTimer = 0;
        this.invincibleTimer = 0;
        this.ghostTimer = 0;
        this.nitro = this.nitroMax;
        this.trailPoints = [];
        this.isDrifting = false;
    }
}

// Export
if (typeof window !== 'undefined') {
    window.Vehicle = Vehicle;
}
