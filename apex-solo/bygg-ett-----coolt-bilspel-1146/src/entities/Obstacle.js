/**
 * GRAVSHIFT - Obstacle Entity
 * Obstacles the player must avoid
 */

class Obstacle {
    constructor(scene, x, y, type = 'BARRIER') {
        this.scene = scene;
        this.x = x;
        this.y = y;
        this.type = type;
        this.config = OBSTACLES[type] || OBSTACLES.BARRIER;
        
        this.width = this.config.width;
        this.height = this.config.height;
        this.color = this.config.color;
        this.damage = this.config.damage;
        this.breakable = this.config.breakable;
        
        this.active = true;
        this.visible = true;
        this.rotation = 0;
        
        // Animation state
        this.animTime = Math.random() * 1000;
        this.pulseSpeed = 2 + Math.random();
        
        // Movement for MOVING type
        this.moves = this.config.moves || false;
        this.moveSpeed = 100;
        this.moveDirection = Math.random() > 0.5 ? 1 : -1;
        this.moveRange = 150;
        this.startX = x;
        
        // Laser animation
        this.laserPhase = 0;
        
        // Screen position for rendering (set by TrackRenderer)
        this.screenX = x;
        this.screenY = y;
        this.screenScale = 1;
        
        this.graphics = null;
    }
    
    /**
     * Update obstacle
     */
    update(deltaTime) {
        if (!this.active) return;
        
        const dt = deltaTime / 1000;
        this.animTime += deltaTime;
        
        // Movement for moving obstacles
        if (this.moves) {
            this.x += this.moveDirection * this.moveSpeed * dt;
            
            if (Math.abs(this.x - this.startX) > this.moveRange) {
                this.moveDirection *= -1;
            }
        }
        
        // Laser animation
        if (this.type === 'LASER') {
            this.laserPhase = (this.laserPhase + deltaTime / 100) % (Math.PI * 2);
        }
        
        // Update rotation for debris
        if (this.type === 'DEBRIS') {
            this.rotation += deltaTime / 1000 * 60; // 60 degrees per second
        }
    }
    
    /**
     * Check if obstacle is on screen
     */
    isOnScreen(cameraY, screenHeight) {
        return this.y > cameraY - this.height &&
               this.y < cameraY + screenHeight + this.height;
    }
    
    /**
     * Create visuals
     */
    createVisuals(scene) {
        this.graphics = scene.add.graphics();
        this.graphics.setDepth(50);
    }
    
    /**
     * Render obstacle
     */
    render(graphics = null) {
        const g = graphics || this.graphics;
        if (!g || !this.visible) return;
        
        if (!graphics) g.clear();
        
        switch (this.type) {
            case 'BARRIER':
                this.renderBarrier(g);
                break;
            case 'SPIKE':
                this.renderSpike(g);
                break;
            case 'DEBRIS':
                this.renderDebris(g);
                break;
            case 'LASER':
                this.renderLaser(g);
                break;
            case 'MOVING':
                this.renderMoving(g);
                break;
            default:
                this.renderBarrier(g);
        }
    }
    
    renderBarrier(g) {
        const pulse = Math.sin(this.animTime / 1000 * this.pulseSpeed) * 0.2 + 0.8;
        
        // Main body
        g.fillStyle(this.color, pulse);
        g.fillRect(
            this.x - this.width / 2,
            this.y - this.height / 2,
            this.width,
            this.height
        );
        
        // Warning stripes
        g.fillStyle(0x000000, 0.4);
        const stripeWidth = this.width / 5;
        for (let i = 0; i < 5; i += 2) {
            g.fillRect(
                this.x - this.width / 2 + i * stripeWidth,
                this.y - this.height / 2,
                stripeWidth,
                this.height
            );
        }
        
        // Glow outline
        g.lineStyle(2, ColorUtils.lighten(this.color, 0.5), pulse);
        g.strokeRect(
            this.x - this.width / 2,
            this.y - this.height / 2,
            this.width,
            this.height
        );
    }
    
    renderSpike(g) {
        const pulse = Math.sin(this.animTime / 1000 * this.pulseSpeed) * 0.2 + 0.8;
        
        // Glow
        g.fillStyle(this.color, 0.3);
        g.fillTriangle(
            this.x, this.y - this.height / 2 - 5,
            this.x - this.width / 2 - 5, this.y + this.height / 2 + 5,
            this.x + this.width / 2 + 5, this.y + this.height / 2 + 5
        );
        
        // Main spike
        g.fillStyle(this.color, pulse);
        g.fillTriangle(
            this.x, this.y - this.height / 2,
            this.x - this.width / 2, this.y + this.height / 2,
            this.x + this.width / 2, this.y + this.height / 2
        );
        
        // Outline
        g.lineStyle(2, ColorUtils.lighten(this.color, 0.5), 1);
        g.strokeTriangle(
            this.x, this.y - this.height / 2,
            this.x - this.width / 2, this.y + this.height / 2,
            this.x + this.width / 2, this.y + this.height / 2
        );
    }
    
    renderDebris(g) {
        const pulse = Math.sin(this.animTime / 1000 * 3) * 0.1 + 0.9;
        
        // Calculate rotated rectangle corners
        const corners = [
            { x: -this.width / 2, y: -this.height / 2 },
            { x: this.width / 2, y: -this.height / 2 },
            { x: this.width / 2, y: this.height / 2 },
            { x: -this.width / 2, y: this.height / 2 },
        ];
        
        const transformed = corners.map(c => {
            const rotated = MathUtils.rotatePoint(c.x, c.y, this.rotation);
            return { x: this.x + rotated.x, y: this.y + rotated.y };
        });
        
        // Draw rotated rectangle as two triangles
        g.fillStyle(this.color, pulse);
        g.fillTriangle(
            transformed[0].x, transformed[0].y,
            transformed[1].x, transformed[1].y,
            transformed[2].x, transformed[2].y
        );
        g.fillTriangle(
            transformed[0].x, transformed[0].y,
            transformed[2].x, transformed[2].y,
            transformed[3].x, transformed[3].y
        );
        
        // Draw cracks as lines
        g.lineStyle(1, 0x444444, 0.5);
        // Crack 1
        const crack1Start = MathUtils.rotatePoint(-this.width / 4, -this.height / 2, this.rotation);
        const crack1End = MathUtils.rotatePoint(0, this.height / 4, this.rotation);
        g.lineBetween(
            this.x + crack1Start.x, this.y + crack1Start.y,
            this.x + crack1End.x, this.y + crack1End.y
        );
        // Crack 2
        const crack2Start = MathUtils.rotatePoint(this.width / 4, -this.height / 4, this.rotation);
        const crack2End = MathUtils.rotatePoint(-this.width / 4, this.height / 2, this.rotation);
        g.lineBetween(
            this.x + crack2Start.x, this.y + crack2Start.y,
            this.x + crack2End.x, this.y + crack2End.y
        );
        
        // Outline
        g.lineStyle(1, ColorUtils.lighten(this.color, 0.3), 0.5);
        g.lineBetween(transformed[0].x, transformed[0].y, transformed[1].x, transformed[1].y);
        g.lineBetween(transformed[1].x, transformed[1].y, transformed[2].x, transformed[2].y);
        g.lineBetween(transformed[2].x, transformed[2].y, transformed[3].x, transformed[3].y);
        g.lineBetween(transformed[3].x, transformed[3].y, transformed[0].x, transformed[0].y);
    }
    
    renderLaser(g) {
        const intensity = Math.sin(this.laserPhase) * 0.5 + 0.5;
        const flicker = Math.random() > 0.95 ? 0.3 : 1;
        
        // Glow
        for (let i = 3; i > 0; i--) {
            g.fillStyle(this.color, intensity * 0.1 / i * flicker);
            g.fillRect(
                this.x - this.width / 2,
                this.y - this.height / 2 - i * 3,
                this.width,
                this.height + i * 6
            );
        }
        
        // Core
        g.fillStyle(0xffffff, intensity * flicker);
        g.fillRect(
            this.x - this.width / 2,
            this.y - 2,
            this.width,
            4
        );
        
        // Beam
        g.fillStyle(this.color, intensity * 0.8 * flicker);
        g.fillRect(
            this.x - this.width / 2,
            this.y - this.height / 2,
            this.width,
            this.height
        );
        
        // Emitters at ends
        g.fillStyle(0xffffff, 1);
        g.fillCircle(this.x - this.width / 2, this.y, 5);
        g.fillCircle(this.x + this.width / 2, this.y, 5);
    }
    
    renderMoving(g) {
        const pulse = Math.sin(this.animTime / 1000 * 4) * 0.3 + 0.7;
        
        // Drone body
        g.fillStyle(this.color, pulse);
        g.fillCircle(this.x, this.y, this.width / 2);
        
        // Inner ring
        g.lineStyle(3, ColorUtils.lighten(this.color, 0.3), 1);
        g.strokeCircle(this.x, this.y, this.width / 3);
        
        // Eye
        g.fillStyle(0xffffff, 1);
        g.fillCircle(this.x, this.y, 5);
        
        // Scanning beam
        const beamAngle = this.animTime / 500;
        g.lineStyle(2, this.color, 0.5);
        g.lineBetween(
            this.x,
            this.y,
            this.x + Math.cos(beamAngle) * 50,
            this.y + Math.sin(beamAngle) * 50
        );
    }
    
    /**
     * Get bounds for collision
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
     * Destroy obstacle (for breakable ones)
     */
    break() {
        if (!this.breakable) return false;
        
        this.active = false;
        this.visible = false;
        
        // Emit break event for particles
        this.scene.events.emit('obstacleDestroyed', this);
        
        return true;
    }
    
    /**
     * Clean up
     */
    destroy() {
        if (this.graphics) {
            this.graphics.destroy();
        }
    }
}

// Export
if (typeof window !== 'undefined') {
    window.Obstacle = Obstacle;
}
