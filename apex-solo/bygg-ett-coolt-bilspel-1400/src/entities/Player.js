/**
 * NEON TRAIL - Player Entity
 * The player's neon racing car
 */

class Player {
    constructor(scene, x, y) {
        this.scene = scene;
        
        // Position and movement
        this.x = x;
        this.y = y;
        this.velocityX = 0;
        this.velocityY = 0;
        this.angle = -Math.PI / 2; // Facing up
        this.speed = PLAYER_CONFIG.BASE_SPEED;
        
        // Dimensions
        this.width = PLAYER_CONFIG.WIDTH;
        this.height = PLAYER_CONFIG.HEIGHT;
        
        // State
        this.isAlive = true;
        this.isDrifting = false;
        this.driftDirection = 0;
        this.driftDuration = 0;
        
        // Power-up states
        this.activePowerUps = new Map();
        this.isInvincible = false;
        this.isGhostMode = false;
        this.speedMultiplier = 1;
        this.trailMultiplier = 1;
        
        // Visual components
        this.container = null;
        this.carBody = null;
        this.carGlow = null;
        this.headlights = null;
        this.taillights = null;
        this.shieldEffect = null;
        
        // Animation
        this.bobOffset = 0;
        this.glowIntensity = 1;
    }
    
    /**
     * Create visual components
     */
    create() {
        // Container for all car parts
        this.container = this.scene.add.container(this.x, this.y);
        this.container.setDepth(50);
        
        // Glow effect (drawn first, underneath)
        this.carGlow = this.scene.add.graphics();
        this.drawCarGlow();
        this.container.add(this.carGlow);
        
        // Car body
        this.carBody = this.scene.add.graphics();
        this.drawCarBody();
        this.container.add(this.carBody);
        
        // Headlights
        this.headlights = this.scene.add.graphics();
        this.drawHeadlights();
        this.container.add(this.headlights);
        
        // Taillights
        this.taillights = this.scene.add.graphics();
        this.drawTaillights();
        this.container.add(this.taillights);
        
        // Shield effect (hidden by default)
        this.shieldEffect = this.scene.add.graphics();
        this.shieldEffect.setVisible(false);
        this.container.add(this.shieldEffect);
        
        return this;
    }
    
    /**
     * Draw the car body
     */
    drawCarBody() {
        const g = this.carBody;
        g.clear();
        
        const w = this.width;
        const h = this.height;
        
        // Main body (trapezoid shape)
        g.fillStyle(GAME_CONFIG.COLORS.DARK_PURPLE, 1);
        g.beginPath();
        g.moveTo(-w/2, h/2);         // Bottom left
        g.lineTo(-w/3, -h/2);        // Top left
        g.lineTo(w/3, -h/2);         // Top right
        g.lineTo(w/2, h/2);          // Bottom right
        g.closePath();
        g.fillPath();
        
        // Body outline (neon)
        g.lineStyle(3, GAME_CONFIG.COLORS.CYAN, 1);
        g.beginPath();
        g.moveTo(-w/2, h/2);
        g.lineTo(-w/3, -h/2);
        g.lineTo(w/3, -h/2);
        g.lineTo(w/2, h/2);
        g.closePath();
        g.strokePath();
        
        // Cockpit
        g.fillStyle(GAME_CONFIG.COLORS.DARK_BLUE, 1);
        g.fillRoundedRect(-w/4, -h/4, w/2, h/3, 4);
        
        // Cockpit glow
        g.lineStyle(2, GAME_CONFIG.COLORS.CYAN, 0.5);
        g.strokeRoundedRect(-w/4, -h/4, w/2, h/3, 4);
        
        // Side details
        g.lineStyle(2, GAME_CONFIG.COLORS.MAGENTA, 0.8);
        g.lineBetween(-w/2 + 5, h/4, -w/3 + 5, -h/4);
        g.lineBetween(w/2 - 5, h/4, w/3 - 5, -h/4);
        
        // Center stripe
        g.lineStyle(2, GAME_CONFIG.COLORS.CYAN, 0.5);
        g.lineBetween(0, -h/2 + 5, 0, h/2 - 10);
    }
    
    /**
     * Draw glow effect
     */
    drawCarGlow() {
        const g = this.carGlow;
        g.clear();
        
        const w = this.width;
        const h = this.height;
        
        // Outer glow
        g.fillStyle(GAME_CONFIG.COLORS.CYAN, 0.1 * this.glowIntensity);
        g.fillEllipse(0, 0, w * 2, h * 1.5);
        
        // Inner glow
        g.fillStyle(GAME_CONFIG.COLORS.CYAN, 0.2 * this.glowIntensity);
        g.fillEllipse(0, 0, w * 1.3, h * 1.1);
    }
    
    /**
     * Draw headlights
     */
    drawHeadlights() {
        const g = this.headlights;
        g.clear();
        
        const h = this.height;
        
        // Left headlight
        g.fillStyle(GAME_CONFIG.COLORS.YELLOW, 0.9);
        g.fillCircle(-10, -h/2 + 5, 4);
        g.fillStyle(GAME_CONFIG.COLORS.YELLOW, 0.3);
        g.fillCircle(-10, -h/2 + 5, 8);
        
        // Right headlight
        g.fillStyle(GAME_CONFIG.COLORS.YELLOW, 0.9);
        g.fillCircle(10, -h/2 + 5, 4);
        g.fillStyle(GAME_CONFIG.COLORS.YELLOW, 0.3);
        g.fillCircle(10, -h/2 + 5, 8);
        
        // Headlight beams
        g.fillStyle(GAME_CONFIG.COLORS.YELLOW, 0.1);
        g.beginPath();
        g.moveTo(-10, -h/2);
        g.lineTo(-25, -h/2 - 60);
        g.lineTo(5, -h/2 - 60);
        g.closePath();
        g.fillPath();
        
        g.beginPath();
        g.moveTo(10, -h/2);
        g.lineTo(-5, -h/2 - 60);
        g.lineTo(25, -h/2 - 60);
        g.closePath();
        g.fillPath();
    }
    
    /**
     * Draw taillights
     */
    drawTaillights() {
        const g = this.taillights;
        g.clear();
        
        const w = this.width;
        const h = this.height;
        
        // Left taillight
        g.fillStyle(GAME_CONFIG.COLORS.MAGENTA, 0.9);
        g.fillRect(-w/2 + 2, h/2 - 8, 8, 6);
        g.fillStyle(GAME_CONFIG.COLORS.MAGENTA, 0.3);
        g.fillRect(-w/2, h/2 - 10, 12, 10);
        
        // Right taillight
        g.fillStyle(GAME_CONFIG.COLORS.MAGENTA, 0.9);
        g.fillRect(w/2 - 10, h/2 - 8, 8, 6);
        g.fillStyle(GAME_CONFIG.COLORS.MAGENTA, 0.3);
        g.fillRect(w/2 - 12, h/2 - 10, 12, 10);
    }
    
    /**
     * Draw shield effect
     */
    drawShield() {
        const g = this.shieldEffect;
        g.clear();
        
        if (!this.isInvincible) {
            g.setVisible(false);
            return;
        }
        
        g.setVisible(true);
        
        const radius = Math.max(this.width, this.height) * 0.8;
        const pulseOffset = Math.sin(this.scene.time.now / 100) * 0.2;
        
        // Outer ring
        g.lineStyle(3, GAME_CONFIG.COLORS.CYAN, 0.5 + pulseOffset);
        g.strokeCircle(0, 0, radius);
        
        // Inner ring
        g.lineStyle(2, GAME_CONFIG.COLORS.CYAN, 0.3 + pulseOffset);
        g.strokeCircle(0, 0, radius * 0.8);
        
        // Fill
        g.fillStyle(GAME_CONFIG.COLORS.CYAN, 0.1 + pulseOffset * 0.1);
        g.fillCircle(0, 0, radius);
    }
    
    /**
     * Update player
     */
    update(delta, inputManager) {
        if (!this.isAlive) return;
        
        // Get input
        const horizontal = inputManager.getHorizontal();
        const isDrifting = inputManager.isDrifting();
        
        // Update drift state
        this.updateDrift(horizontal, isDrifting, delta);
        
        // Calculate movement
        this.updateMovement(horizontal, delta);
        
        // Constrain to road bounds
        this.constrainToBounds();
        
        // Update visuals
        this.updateVisuals(delta);
        
        // Update container position
        this.container.setPosition(this.x, this.y);
        
        // Update power-ups
        this.updatePowerUps(delta);
    }
    
    /**
     * Update drift mechanics
     */
    updateDrift(horizontal, isDrifting, delta) {
        const wasDrifting = this.isDrifting;
        
        // Start drift
        if (isDrifting && Math.abs(horizontal) > PLAYER_CONFIG.DRIFT_THRESHOLD) {
            this.isDrifting = true;
            this.driftDirection = Math.sign(horizontal);
            this.driftDuration += delta / 1000;
        } else {
            // End drift
            if (this.isDrifting && this.driftDuration > 0.5) {
                // Drift ended - award points via callback
                if (this.onDriftEnd) {
                    this.onDriftEnd(this.driftDuration);
                }
            }
            this.isDrifting = false;
            this.driftDuration = 0;
        }
        
        // Drift started callback
        if (this.isDrifting && !wasDrifting) {
            if (this.onDriftStart) {
                this.onDriftStart();
            }
        }
    }
    
    /**
     * Update movement physics
     */
    updateMovement(horizontal, delta) {
        // Base turn speed
        let turnSpeed = PLAYER_CONFIG.TURN_SPEED;
        
        // Drift multiplier
        if (this.isDrifting) {
            turnSpeed *= PLAYER_CONFIG.DRIFT_MULTIPLIER;
        }
        
        // Apply horizontal movement
        this.velocityX += horizontal * turnSpeed * (delta / 16);
        
        // Friction
        this.velocityX *= PLAYER_CONFIG.FRICTION;
        
        // Update position
        this.x += this.velocityX;
        
        // Update visual angle based on velocity
        const targetAngle = -Math.PI / 2 + (this.velocityX / 50) * 0.3;
        this.angle = Phaser.Math.Linear(this.angle, targetAngle, 0.1);
        
        // Apply speed
        const currentSpeed = this.speed * this.speedMultiplier;
        this.velocityY = -currentSpeed * (delta / 1000);
    }
    
    /**
     * Constrain player to road bounds
     */
    constrainToBounds() {
        const roadLeft = (GAME_CONFIG.WIDTH - ROAD_CONFIG.WIDTH) / 2 + this.width / 2;
        const roadRight = (GAME_CONFIG.WIDTH + ROAD_CONFIG.WIDTH) / 2 - this.width / 2;
        
        if (this.x < roadLeft) {
            this.x = roadLeft;
            this.velocityX = Math.abs(this.velocityX) * PLAYER_CONFIG.BOUNCE;
        }
        if (this.x > roadRight) {
            this.x = roadRight;
            this.velocityX = -Math.abs(this.velocityX) * PLAYER_CONFIG.BOUNCE;
        }
    }
    
    /**
     * Update visual effects
     */
    updateVisuals(delta) {
        // Bobbing animation
        this.bobOffset = Math.sin(this.scene.time.now / 200) * 2;
        this.container.y = this.y + this.bobOffset;
        
        // Rotation based on drift
        const driftRotation = this.isDrifting ? this.driftDirection * 0.2 : 0;
        this.container.rotation = this.angle + Math.PI / 2 + driftRotation;
        
        // Glow intensity pulsing
        this.glowIntensity = 0.8 + Math.sin(this.scene.time.now / 300) * 0.2;
        this.drawCarGlow();
        
        // Update shield
        this.drawShield();
        
        // Boost effect
        if (this.speedMultiplier > 1) {
            this.taillights.setAlpha(0.5 + Math.random() * 0.5);
        } else {
            this.taillights.setAlpha(1);
        }
    }
    
    /**
     * Update active power-ups
     */
    updatePowerUps(delta) {
        const now = this.scene.time.now;
        
        this.activePowerUps.forEach((endTime, type) => {
            if (now >= endTime) {
                this.deactivatePowerUp(type);
            }
        });
    }
    
    /**
     * Activate a power-up
     */
    activatePowerUp(type) {
        const config = POWERUP_CONFIG.TYPES[type];
        if (!config) return;
        
        const endTime = this.scene.time.now + config.duration;
        this.activePowerUps.set(type, endTime);
        
        switch (config.effect) {
            case 'speed_boost':
                this.speedMultiplier = config.multiplier;
                break;
            case 'phase_through_trail':
                this.isGhostMode = true;
                break;
            case 'smaller_trail':
                this.trailMultiplier = config.multiplier;
                break;
            case 'slow_time':
                // Handled by game scene
                break;
            case 'invincibility':
                this.isInvincible = true;
                break;
        }
        
        // Callback
        if (this.onPowerUpActivate) {
            this.onPowerUpActivate(type, config);
        }
    }
    
    /**
     * Deactivate a power-up
     */
    deactivatePowerUp(type) {
        const config = POWERUP_CONFIG.TYPES[type];
        if (!config) return;
        
        this.activePowerUps.delete(type);
        
        switch (config.effect) {
            case 'speed_boost':
                this.speedMultiplier = 1;
                break;
            case 'phase_through_trail':
                this.isGhostMode = false;
                break;
            case 'smaller_trail':
                this.trailMultiplier = 1;
                break;
            case 'slow_time':
                // Handled by game scene
                break;
            case 'invincibility':
                this.isInvincible = false;
                break;
        }
        
        // Callback
        if (this.onPowerUpDeactivate) {
            this.onPowerUpDeactivate(type);
        }
    }
    
    /**
     * Check if power-up is active
     */
    hasPowerUp(type) {
        return this.activePowerUps.has(type);
    }
    
    /**
     * Get collision bounds
     */
    getBounds() {
        const padding = PLAYER_CONFIG.HITBOX_PADDING;
        return {
            x: this.x - this.width / 2 + padding,
            y: this.y - this.height / 2 + padding,
            width: this.width - padding * 2,
            height: this.height - padding * 2,
        };
    }
    
    /**
     * Get collision radius
     */
    getCollisionRadius() {
        return Math.min(this.width, this.height) / 2 - PLAYER_CONFIG.HITBOX_PADDING;
    }
    
    /**
     * Get center position for trail
     */
    getTrailPosition() {
        // Emit from back of car
        const backOffset = this.height / 2;
        return {
            x: this.x,
            y: this.y + backOffset,
            angle: this.angle,
        };
    }
    
    /**
     * Handle collision
     */
    hit() {
        if (this.isInvincible) return false;
        
        this.isAlive = false;
        
        // Death animation
        this.scene.tweens.add({
            targets: this.container,
            alpha: 0,
            scale: 1.5,
            rotation: this.container.rotation + Math.PI,
            duration: 500,
            ease: 'Power2',
        });
        
        return true;
    }
    
    /**
     * Reset player
     */
    reset(x, y) {
        this.x = x;
        this.y = y;
        this.velocityX = 0;
        this.velocityY = 0;
        this.angle = -Math.PI / 2;
        this.isAlive = true;
        this.isDrifting = false;
        this.driftDuration = 0;
        this.activePowerUps.clear();
        this.isInvincible = false;
        this.isGhostMode = false;
        this.speedMultiplier = 1;
        this.trailMultiplier = 1;
        
        if (this.container) {
            this.container.setPosition(x, y);
            this.container.setAlpha(1);
            this.container.setScale(1);
            this.container.setRotation(0);
        }
    }
    
    /**
     * Cleanup
     */
    destroy() {
        if (this.container) {
            this.container.destroy();
            this.container = null;
        }
        
        this.onDriftStart = null;
        this.onDriftEnd = null;
        this.onPowerUpActivate = null;
        this.onPowerUpDeactivate = null;
    }
}
