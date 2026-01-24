/**
 * NEON TRAIL - Obstacle Entity
 * Various obstacles the player must avoid
 */

class Obstacle {
    constructor(scene, x, y, type) {
        this.scene = scene;
        this.x = x;
        this.y = y;
        this.type = type;
        
        // Dimensions based on type
        this.setupDimensions();
        
        // State
        this.isActive = true;
        this.hasBeenPassed = false;
        
        // Movement (for moving obstacles)
        this.velocityX = 0;
        this.velocityY = 0;
        this.moveDirection = 1;
        
        // Visual components
        this.container = null;
        this.graphics = null;
        this.glowGraphics = null;
    }
    
    /**
     * Setup dimensions based on obstacle type
     */
    setupDimensions() {
        switch (this.type) {
            case OBSTACLE_CONFIG.TYPES.BARRIER:
                this.width = OBSTACLE_CONFIG.BARRIER_WIDTH;
                this.height = OBSTACLE_CONFIG.BARRIER_HEIGHT;
                this.color = GAME_CONFIG.COLORS.MAGENTA;
                break;
            case OBSTACLE_CONFIG.TYPES.CONE:
                this.width = OBSTACLE_CONFIG.CONE_SIZE;
                this.height = OBSTACLE_CONFIG.CONE_SIZE;
                this.color = GAME_CONFIG.COLORS.ORANGE;
                break;
            case OBSTACLE_CONFIG.TYPES.OIL:
                this.width = OBSTACLE_CONFIG.OIL_SIZE;
                this.height = OBSTACLE_CONFIG.OIL_SIZE;
                this.color = GAME_CONFIG.COLORS.GRAY;
                this.isHazard = true; // Affects player but doesn't kill
                break;
            case OBSTACLE_CONFIG.TYPES.WALL:
                this.width = OBSTACLE_CONFIG.BARRIER_WIDTH;
                this.height = OBSTACLE_CONFIG.BARRIER_HEIGHT * 2;
                this.color = GAME_CONFIG.COLORS.MAGENTA;
                break;
            case OBSTACLE_CONFIG.TYPES.MOVING:
                this.width = OBSTACLE_CONFIG.CONE_SIZE * 1.5;
                this.height = OBSTACLE_CONFIG.CONE_SIZE * 1.5;
                this.color = GAME_CONFIG.COLORS.YELLOW;
                this.velocityX = Phaser.Math.Between(
                    OBSTACLE_CONFIG.MOVING_SPEED_MIN,
                    OBSTACLE_CONFIG.MOVING_SPEED_MAX
                ) * this.moveDirection;
                break;
            default:
                this.width = 40;
                this.height = 40;
                this.color = GAME_CONFIG.COLORS.MAGENTA;
        }
    }
    
    /**
     * Create visual components
     */
    create() {
        this.container = this.scene.add.container(this.x, this.y);
        this.container.setDepth(30);
        
        // Glow effect
        this.glowGraphics = this.scene.add.graphics();
        this.container.add(this.glowGraphics);
        
        // Main graphics
        this.graphics = this.scene.add.graphics();
        this.container.add(this.graphics);
        
        // Draw based on type
        this.draw();
        
        // Spawn animation
        this.container.setScale(0);
        this.scene.tweens.add({
            targets: this.container,
            scale: 1,
            duration: 200,
            ease: 'Back.easeOut',
        });
        
        return this;
    }
    
    /**
     * Draw obstacle based on type
     */
    draw() {
        this.graphics.clear();
        this.glowGraphics.clear();
        
        switch (this.type) {
            case OBSTACLE_CONFIG.TYPES.BARRIER:
                this.drawBarrier();
                break;
            case OBSTACLE_CONFIG.TYPES.CONE:
                this.drawCone();
                break;
            case OBSTACLE_CONFIG.TYPES.OIL:
                this.drawOil();
                break;
            case OBSTACLE_CONFIG.TYPES.WALL:
                this.drawWall();
                break;
            case OBSTACLE_CONFIG.TYPES.MOVING:
                this.drawMoving();
                break;
            default:
                this.drawDefault();
        }
    }
    
    /**
     * Draw barrier obstacle
     */
    drawBarrier() {
        const g = this.graphics;
        const glow = this.glowGraphics;
        const w = this.width;
        const h = this.height;
        
        // Glow
        glow.fillStyle(this.color, 0.2);
        glow.fillRoundedRect(-w/2 - 5, -h/2 - 5, w + 10, h + 10, 4);
        
        // Body
        g.fillStyle(GAME_CONFIG.COLORS.DARK_PURPLE, 1);
        g.fillRoundedRect(-w/2, -h/2, w, h, 2);
        
        // Outline
        g.lineStyle(3, this.color, 1);
        g.strokeRoundedRect(-w/2, -h/2, w, h, 2);
        
        // Warning stripes
        g.lineStyle(2, GAME_CONFIG.COLORS.YELLOW, 0.8);
        const stripeSpacing = 15;
        for (let i = -w/2 + 10; i < w/2 - 5; i += stripeSpacing) {
            g.lineBetween(i, -h/2 + 3, i + 10, h/2 - 3);
        }
    }
    
    /**
     * Draw cone obstacle
     */
    drawCone() {
        const g = this.graphics;
        const glow = this.glowGraphics;
        const size = this.width;
        
        // Glow
        glow.fillStyle(this.color, 0.2);
        glow.fillCircle(0, 0, size * 0.8);
        
        // Base
        g.fillStyle(GAME_CONFIG.COLORS.DARK_PURPLE, 1);
        g.fillCircle(0, size * 0.2, size * 0.4);
        
        // Cone body (triangle)
        g.fillStyle(this.color, 1);
        g.beginPath();
        g.moveTo(0, -size * 0.4);
        g.lineTo(-size * 0.3, size * 0.2);
        g.lineTo(size * 0.3, size * 0.2);
        g.closePath();
        g.fillPath();
        
        // Outline
        g.lineStyle(2, GAME_CONFIG.COLORS.WHITE, 0.8);
        g.beginPath();
        g.moveTo(0, -size * 0.4);
        g.lineTo(-size * 0.3, size * 0.2);
        g.lineTo(size * 0.3, size * 0.2);
        g.closePath();
        g.strokePath();
        
        // Reflective stripe
        g.lineStyle(3, GAME_CONFIG.COLORS.WHITE, 0.9);
        g.lineBetween(-size * 0.15, -size * 0.1, size * 0.15, -size * 0.1);
    }
    
    /**
     * Draw oil slick
     */
    drawOil() {
        const g = this.graphics;
        const glow = this.glowGraphics;
        const size = this.width;
        
        // No glow for oil
        
        // Oil puddle (irregular shape using multiple ellipses)
        g.fillStyle(0x1a1a2e, 0.8);
        g.fillEllipse(0, 0, size, size * 0.7);
        
        g.fillStyle(0x2a2a4e, 0.6);
        g.fillEllipse(-size * 0.1, size * 0.1, size * 0.6, size * 0.4);
        
        // Iridescent effect
        g.fillStyle(GAME_CONFIG.COLORS.MAGENTA, 0.2);
        g.fillEllipse(size * 0.1, -size * 0.1, size * 0.4, size * 0.3);
        
        g.fillStyle(GAME_CONFIG.COLORS.CYAN, 0.15);
        g.fillEllipse(-size * 0.15, 0, size * 0.3, size * 0.2);
        
        // Edge highlight
        g.lineStyle(1, GAME_CONFIG.COLORS.GRAY, 0.3);
        g.strokeEllipse(0, 0, size, size * 0.7);
    }
    
    /**
     * Draw wall obstacle
     */
    drawWall() {
        const g = this.graphics;
        const glow = this.glowGraphics;
        const w = this.width;
        const h = this.height;
        
        // Glow
        glow.fillStyle(this.color, 0.3);
        glow.fillRoundedRect(-w/2 - 8, -h/2 - 8, w + 16, h + 16, 4);
        
        // Body
        g.fillStyle(GAME_CONFIG.COLORS.DARK_PURPLE, 1);
        g.fillRoundedRect(-w/2, -h/2, w, h, 4);
        
        // Outline
        g.lineStyle(4, this.color, 1);
        g.strokeRoundedRect(-w/2, -h/2, w, h, 4);
        
        // X pattern
        g.lineStyle(3, GAME_CONFIG.COLORS.YELLOW, 0.8);
        g.lineBetween(-w/2 + 10, -h/2 + 10, w/2 - 10, h/2 - 10);
        g.lineBetween(w/2 - 10, -h/2 + 10, -w/2 + 10, h/2 - 10);
        
        // Warning text effect
        g.lineStyle(2, GAME_CONFIG.COLORS.WHITE, 0.5);
        g.lineBetween(-w/4, 0, w/4, 0);
    }
    
    /**
     * Draw moving obstacle
     */
    drawMoving() {
        const g = this.graphics;
        const glow = this.glowGraphics;
        const size = this.width;
        
        // Animated glow
        const pulseOffset = Math.sin(this.scene.time.now / 150) * 0.2;
        glow.fillStyle(this.color, 0.3 + pulseOffset);
        glow.fillCircle(0, 0, size * 0.8);
        
        // Diamond shape
        g.fillStyle(GAME_CONFIG.COLORS.DARK_PURPLE, 1);
        g.beginPath();
        g.moveTo(0, -size * 0.4);
        g.lineTo(size * 0.4, 0);
        g.lineTo(0, size * 0.4);
        g.lineTo(-size * 0.4, 0);
        g.closePath();
        g.fillPath();
        
        // Outline
        g.lineStyle(3, this.color, 1);
        g.beginPath();
        g.moveTo(0, -size * 0.4);
        g.lineTo(size * 0.4, 0);
        g.lineTo(0, size * 0.4);
        g.lineTo(-size * 0.4, 0);
        g.closePath();
        g.strokePath();
        
        // Direction indicator
        const arrowDir = this.velocityX > 0 ? 1 : -1;
        g.fillStyle(GAME_CONFIG.COLORS.WHITE, 0.8);
        g.beginPath();
        g.moveTo(arrowDir * size * 0.15, -5);
        g.lineTo(arrowDir * size * 0.25, 0);
        g.lineTo(arrowDir * size * 0.15, 5);
        g.closePath();
        g.fillPath();
    }
    
    /**
     * Draw default obstacle
     */
    drawDefault() {
        const g = this.graphics;
        
        g.fillStyle(this.color, 1);
        g.fillRect(-this.width/2, -this.height/2, this.width, this.height);
        
        g.lineStyle(2, GAME_CONFIG.COLORS.WHITE, 0.5);
        g.strokeRect(-this.width/2, -this.height/2, this.width, this.height);
    }
    
    /**
     * Update obstacle
     */
    update(delta, scrollSpeed) {
        if (!this.isActive) return;
        
        // Move down with road
        this.y += scrollSpeed;
        
        // Moving obstacles
        if (this.type === OBSTACLE_CONFIG.TYPES.MOVING) {
            this.x += this.velocityX * (delta / 1000);
            
            // Bounce off road edges
            const roadLeft = (GAME_CONFIG.WIDTH - ROAD_CONFIG.WIDTH) / 2 + this.width / 2;
            const roadRight = (GAME_CONFIG.WIDTH + ROAD_CONFIG.WIDTH) / 2 - this.width / 2;
            
            if (this.x <= roadLeft || this.x >= roadRight) {
                this.velocityX *= -1;
                this.draw(); // Redraw to update direction indicator
            }
            
            this.x = Phaser.Math.Clamp(this.x, roadLeft, roadRight);
        }
        
        // Update container position
        if (this.container) {
            this.container.setPosition(this.x, this.y);
        }
        
        // Deactivate if off screen
        if (this.y > GAME_CONFIG.HEIGHT + 100) {
            this.deactivate();
        }
    }
    
    /**
     * Check collision with player
     */
    checkCollision(playerBounds) {
        if (!this.isActive) return false;
        
        // Simple AABB collision
        const obstacleBounds = this.getBounds();
        
        return Phaser.Geom.Intersects.RectangleToRectangle(
            new Phaser.Geom.Rectangle(playerBounds.x, playerBounds.y, playerBounds.width, playerBounds.height),
            new Phaser.Geom.Rectangle(obstacleBounds.x, obstacleBounds.y, obstacleBounds.width, obstacleBounds.height)
        );
    }
    
    /**
     * Check near miss (close but not colliding)
     */
    checkNearMiss(playerBounds, nearMissDistance = 30) {
        if (!this.isActive || this.hasBeenPassed) return false;
        
        const obstacleBounds = this.getBounds();
        
        // Expand obstacle bounds for near miss detection
        const expandedBounds = {
            x: obstacleBounds.x - nearMissDistance,
            y: obstacleBounds.y - nearMissDistance,
            width: obstacleBounds.width + nearMissDistance * 2,
            height: obstacleBounds.height + nearMissDistance * 2,
        };
        
        const isNear = Phaser.Geom.Intersects.RectangleToRectangle(
            new Phaser.Geom.Rectangle(playerBounds.x, playerBounds.y, playerBounds.width, playerBounds.height),
            new Phaser.Geom.Rectangle(expandedBounds.x, expandedBounds.y, expandedBounds.width, expandedBounds.height)
        );
        
        // Check if player has passed this obstacle
        if (playerBounds.y + playerBounds.height < this.y - this.height / 2) {
            this.hasBeenPassed = true;
        }
        
        return isNear && !this.checkCollision(playerBounds);
    }
    
    /**
     * Get collision bounds
     */
    getBounds() {
        return {
            x: this.x - this.width / 2,
            y: this.y - this.height / 2,
            width: this.width,
            height: this.height,
        };
    }
    
    /**
     * Check if this is a hazard (affects but doesn't kill)
     */
    isHazardType() {
        return this.type === OBSTACLE_CONFIG.TYPES.OIL;
    }
    
    /**
     * Apply hazard effect to player
     */
    applyHazardEffect(player) {
        if (this.type === OBSTACLE_CONFIG.TYPES.OIL) {
            // Make player slide
            player.velocityX *= 1.5;
            return 'slip';
        }
        return null;
    }
    
    /**
     * Deactivate obstacle
     */
    deactivate() {
        this.isActive = false;
        
        if (this.container) {
            this.container.setVisible(false);
        }
    }
    
    /**
     * Destroy obstacle
     */
    destroy() {
        if (this.container) {
            this.container.destroy();
            this.container = null;
        }
        this.graphics = null;
        this.glowGraphics = null;
    }
}

/**
 * Obstacle Pool for performance
 */
class ObstaclePool {
    constructor(scene, poolSize = 50) {
        this.scene = scene;
        this.pool = [];
        this.activeObstacles = [];
        
        // Pre-create obstacles
        for (let i = 0; i < poolSize; i++) {
            const obstacle = new Obstacle(scene, 0, -100, OBSTACLE_CONFIG.TYPES.CONE);
            obstacle.isActive = false;
            this.pool.push(obstacle);
        }
    }
    
    /**
     * Get an obstacle from the pool
     */
    spawn(x, y, type) {
        let obstacle = this.pool.find(o => !o.isActive);
        
        if (!obstacle) {
            // Create new if pool exhausted
            obstacle = new Obstacle(this.scene, x, y, type);
            this.pool.push(obstacle);
        }
        
        // Reset obstacle
        obstacle.x = x;
        obstacle.y = y;
        obstacle.type = type;
        obstacle.isActive = true;
        obstacle.hasBeenPassed = false;
        obstacle.setupDimensions();
        obstacle.create();
        
        this.activeObstacles.push(obstacle);
        
        return obstacle;
    }
    
    /**
     * Update all active obstacles
     */
    update(delta, scrollSpeed) {
        this.activeObstacles = this.activeObstacles.filter(obstacle => {
            obstacle.update(delta, scrollSpeed);
            
            if (!obstacle.isActive) {
                obstacle.destroy();
                return false;
            }
            return true;
        });
    }
    
    /**
     * Get all active obstacles
     */
    getActive() {
        return this.activeObstacles;
    }
    
    /**
     * Clear all obstacles
     */
    clear() {
        this.activeObstacles.forEach(obstacle => obstacle.destroy());
        this.activeObstacles = [];
    }
    
    /**
     * Destroy pool
     */
    destroy() {
        this.clear();
        this.pool.forEach(obstacle => {
            if (obstacle.container) {
                obstacle.destroy();
            }
        });
        this.pool = [];
    }
}
