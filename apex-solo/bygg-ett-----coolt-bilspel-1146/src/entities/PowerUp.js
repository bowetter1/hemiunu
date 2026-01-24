/**
 * GRAVSHIFT - PowerUp Entity
 * Collectible power-ups with various effects
 */

class PowerUp {
    constructor(scene, x, y, type = 'BOOST') {
        this.scene = scene;
        this.x = x;
        this.y = y;
        this.type = type;
        this.config = POWERUPS[type] || POWERUPS.BOOST;
        
        this.name = this.config.name;
        this.duration = this.config.duration;
        this.color = this.config.color;
        this.effect = this.config.effect;
        
        this.active = true;
        this.visible = true;
        this.collected = false;
        this.radius = 25;
        
        // Animation
        this.animTime = Math.random() * 1000;
        this.bobOffset = 0;
        this.rotationAngle = 0;
        this.pulseScale = 1;
        
        // Screen position for rendering (set by TrackRenderer)
        this.screenX = x;
        this.screenY = y;
        this.screenScale = 1;
        
        this.graphics = null;
    }
    
    /**
     * Update power-up
     */
    update(deltaTime) {
        if (!this.active || this.collected) return;
        
        this.animTime += deltaTime;
        
        // Bob up and down
        this.bobOffset = Math.sin(this.animTime / 300) * 5;
        
        // Rotate
        this.rotationAngle += deltaTime / 1000 * 2;
        
        // Pulse
        this.pulseScale = 1 + Math.sin(this.animTime / 200) * 0.1;
    }
    
    /**
     * Create visuals
     */
    createVisuals(scene) {
        this.graphics = scene.add.graphics();
        this.graphics.setDepth(60);
    }
    
    /**
     * Render power-up
     */
    render(graphics = null) {
        const g = graphics || this.graphics;
        if (!g || !this.visible || this.collected) return;
        
        if (!graphics) g.clear();
        
        const x = this.x;
        const y = this.y + this.bobOffset;
        const r = this.radius * this.pulseScale;
        
        // Outer glow rings
        for (let i = 4; i > 0; i--) {
            const alpha = 0.1 / i;
            const ringR = r + i * 8;
            g.lineStyle(2, this.color, alpha);
            g.strokeCircle(x, y, ringR);
        }
        
        // Main glow
        for (let i = r + 10; i > r; i--) {
            const alpha = (r + 10 - i) / 10 * 0.3;
            g.fillStyle(this.color, alpha);
            g.fillCircle(x, y, i);
        }
        
        // Core orb
        g.fillStyle(this.color, 0.9);
        g.fillCircle(x, y, r * 0.7);
        
        // Inner highlight
        g.fillStyle(0xffffff, 0.6);
        g.fillCircle(x - r * 0.2, y - r * 0.2, r * 0.25);
        
        // Icon based on type
        this.renderIcon(g, x, y, r);
        
        // Orbiting particles
        this.renderOrbitingParticles(g, x, y, r);
    }
    
    /**
     * Render type-specific icon
     */
    renderIcon(g, x, y, r) {
        g.fillStyle(0xffffff, 0.9);
        g.lineStyle(2, 0xffffff, 0.9);
        
        switch (this.type) {
            case 'BOOST':
                // Up arrow
                g.fillTriangle(
                    x, y - r * 0.4,
                    x - r * 0.3, y + r * 0.2,
                    x + r * 0.3, y + r * 0.2
                );
                g.fillRect(x - r * 0.15, y, r * 0.3, r * 0.3);
                break;
                
            case 'SHIELD':
                // Shield shape - use circles instead of arc
                g.lineStyle(3, 0xffffff, 0.9);
                g.strokeCircle(x, y, r * 0.4);
                // Inner shield detail
                g.lineStyle(2, 0xffffff, 0.5);
                g.strokeCircle(x, y, r * 0.25);
                break;
                
            case 'SLOWMO':
                // Clock - use lines
                g.lineStyle(2, 0xffffff, 0.9);
                g.strokeCircle(x, y, r * 0.35);
                // Hour hand
                g.lineBetween(x, y, x, y - r * 0.25);
                // Minute hand
                g.lineBetween(x, y, x + r * 0.2, y);
                // Center dot
                g.fillStyle(0xffffff, 0.9);
                g.fillCircle(x, y, 3);
                break;
                
            case 'MAGNET':
                // U-magnet shape
                g.fillStyle(0xffffff, 0.9);
                g.fillRect(x - r * 0.35, y - r * 0.2, r * 0.2, r * 0.5);
                g.fillRect(x + r * 0.15, y - r * 0.2, r * 0.2, r * 0.5);
                g.fillRect(x - r * 0.35, y - r * 0.35, r * 0.7, r * 0.15);
                // Magnetic lines
                g.lineStyle(1, 0xffffff, 0.4);
                g.lineBetween(x - r * 0.5, y + r * 0.4, x + r * 0.5, y + r * 0.4);
                g.lineBetween(x - r * 0.4, y + r * 0.5, x + r * 0.4, y + r * 0.5);
                break;
                
            case 'GHOST':
                // Ghost outline - concentric fading circles
                g.lineStyle(2, 0xffffff, 0.6);
                g.strokeCircle(x, y, r * 0.3);
                g.lineStyle(1, 0xffffff, 0.3);
                g.strokeCircle(x, y, r * 0.45);
                g.lineStyle(1, 0xffffff, 0.15);
                g.strokeCircle(x, y, r * 0.55);
                break;
        }
    }
    
    /**
     * Render orbiting particles
     */
    renderOrbitingParticles(g, x, y, r) {
        const particleCount = 3;
        const orbitRadius = r * 1.2;
        
        for (let i = 0; i < particleCount; i++) {
            const angle = this.rotationAngle + (i / particleCount) * Math.PI * 2;
            const px = x + Math.cos(angle) * orbitRadius;
            const py = y + Math.sin(angle) * orbitRadius;
            
            g.fillStyle(this.color, 0.8);
            g.fillCircle(px, py, 3);
            
            // Trail
            for (let t = 1; t <= 3; t++) {
                const trailAngle = angle - t * 0.2;
                const tx = x + Math.cos(trailAngle) * orbitRadius;
                const ty = y + Math.sin(trailAngle) * orbitRadius;
                g.fillStyle(this.color, 0.3 / t);
                g.fillCircle(tx, ty, 2);
            }
        }
    }
    
    /**
     * Collect the power-up
     */
    collect(player) {
        if (this.collected) return null;
        
        this.collected = true;
        this.visible = false;
        this.active = false;
        
        // Apply effect to player
        player.applyPowerup(this.type, this.duration);
        
        // Emit event
        this.scene.events.emit('powerupCollected', {
            type: this.type,
            name: this.name,
            x: this.x,
            y: this.y,
            color: this.color,
        });
        
        return {
            type: this.type,
            effect: this.effect,
            duration: this.duration,
        };
    }
    
    /**
     * Get bounds for collision
     */
    getBounds() {
        return {
            x: this.x - this.radius,
            y: this.y - this.radius,
            width: this.radius * 2,
            height: this.radius * 2,
            centerX: this.x,
            centerY: this.y,
        };
    }
    
    /**
     * Check if on screen
     */
    isOnScreen(cameraY, screenHeight) {
        return this.y > cameraY - this.radius * 2 &&
               this.y < cameraY + screenHeight + this.radius * 2;
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
    window.PowerUp = PowerUp;
}
